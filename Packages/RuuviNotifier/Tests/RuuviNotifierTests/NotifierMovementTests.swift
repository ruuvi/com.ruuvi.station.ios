import Foundation
import RuuviLocal
import RuuviNotifier
import RuuviOntology
import RuuviService
#if SWIFT_PACKAGE
    @testable import RuuviNotifierImpl
#else
    @testable import RuuviNotifier
#endif
import XCTest

@MainActor final class NotifierMovementTests: XCTestCase {
    func testFirstCounterEstablishesBaselineThenMovementNotifiesOnceAndAdvancesBaseline() async {
        let fixture = NotifierFixture()
        defer { fixture.close() }
        fixture.alerts.alerts = ["movement": .movement(last: 0)]
        var record = fixture.record()
        record.movementCounter = 10
        await fixture.process(record, network: false)
        XCTAssertEqual(fixture.alerts.movementBaselines.compactMap { $0 }, [10])
        XCTAssertTrue(fixture.notifications.moves.isEmpty)
        XCTAssertEqual(fixture.observer.overall.first?.1, false)
        record.movementCounter = 11
        await fixture.process(record, network: false)
        XCTAssertEqual(fixture.notifications.moves.count, 1)
        XCTAssertEqual(fixture.notifications.moves.first?.0, fixture.luid.value)
        XCTAssertEqual(fixture.notifications.moves.first?.1, 11)
        XCTAssertEqual(fixture.notifications.moves.first?.2, "movement")
        XCTAssertEqual(fixture.alerts.movementBaselines.compactMap { $0 }, [10, 11])
        await fixture.process(record, network: false)
        XCTAssertEqual(fixture.notifications.moves.count, 1)
        record.movementCounter = nil
        await fixture.process(record, network: false)
        XCTAssertEqual(fixture.observer.overall.first?.1, false)
    }

    func testMovementBellRemainsActiveUntilExpiryAndTimerClearsOnlyExpiredSensors() async throws {
        let fixture = NotifierFixture()
        defer { fixture.close() }
        fixture.settings.movementAlertHysteresisMinutes = 1
        fixture.alerts.enabledMovementIDs = [fixture.luid.value, "later"]
        fixture.settings.setMovementAlertHysteresisLastEvents(["later": fixture.clock.date.addingTimeInterval(30)])
        fixture.rebuild()
        fixture.alerts.alerts = ["movement": .movement(last: 1)]
        var record = fixture.record()
        record.movementCounter = 2
        await fixture.process(record, network: false)
        XCTAssertEqual(fixture.settings.movementAlertHysteresisLastEvents()[fixture.luid.value], fixture.clock.date)
        await fixture.process(record, network: false)
        XCTAssertEqual(fixture.observer.overall.first?.1, true)
        fixture.clock.date.addTimeInterval(61)
        try XCTUnwrap(fixture.notifier.movementAlertHysteresisTimer).fire()
        await fixture.drain()
        XCTAssertNil(fixture.settings.movementAlertHysteresisLastEvents()[fixture.luid.value])
        XCTAssertNotNil(fixture.settings.movementAlertHysteresisLastEvents()["later"])
        XCTAssertEqual(fixture.observer.types.last { $0.1.rawValue == "movement" }?.2, false)
        fixture.clock.date.addTimeInterval(31)
        try XCTUnwrap(fixture.notifier.movementAlertHysteresisTimer).fire()
        await fixture.drain()
        XCTAssertTrue(fixture.settings.movementAlertHysteresisLastEvents().isEmpty)
        XCTAssertEqual(fixture.observer.types.last { $0.1.rawValue == "movement" }?.2, false)
        XCTAssertNil(fixture.notifier.movementAlertHysteresisTimer)
    }

    func testProtocolBasedClearRemovesPersistedHysteresisAndUpdatesObservers() async {
        let fixture = NotifierFixture()
        defer { fixture.close() }
        fixture.settings.movementAlertHysteresisMinutes = 5
        fixture.alerts.enabledMovementIDs = [fixture.luid.value]
        fixture.alerts.alerts = ["movement": .movement(last: 1)]
        var record = fixture.record()
        record.movementCounter = 2
        await fixture.process(record, network: false)
        XCTAssertFalse(fixture.settings.movementAlertHysteresisLastEvents().isEmpty)
        let notifier: RuuviNotifier = fixture.notifier
        notifier.clearMovementAlertHysteresis(for: fixture.luid.value)
        await fixture.drain()
        XCTAssertTrue(fixture.settings.movementAlertHysteresisLastEvents().isEmpty)
        XCTAssertEqual(fixture.observer.types.last { $0.1.rawValue == "movement" }?.2, false)
    }

    func testRestoringHysteresisRemovesDisabledAlertsFromPersistentStorageEvenWhenOtherAlertsRemainActive() async {
        let fixture = NotifierFixture()
        defer { fixture.close() }
        fixture.settings.movementAlertHysteresisMinutes = 5
        fixture.alerts.enabledMovementIDs = [fixture.luid.value]
        fixture.settings.setMovementAlertHysteresisLastEvents([
            fixture.luid.value: fixture.clock.date, "disabled": fixture.clock.date,
        ])
        fixture.rebuild()
        await fixture.drain()
        XCTAssertEqual(
            fixture.notifier.movementAlertHysteresisLastEventByUUID, [fixture.luid.value: fixture.clock.date])
        XCTAssertEqual(fixture.settings.movementAlertHysteresisLastEvents(), [fixture.luid.value: fixture.clock.date])
    }

    func testDisabledHysteresisExpiredEventsAndTurningOffMovementRemoveStoredState() async throws {
        let fixture = NotifierFixture()
        defer { fixture.close() }
        fixture.settings.movementAlertHysteresisMinutes = 1
        fixture.alerts.enabledMovementIDs = [fixture.luid.value]
        fixture.settings.setMovementAlertHysteresisLastEvents([
            fixture.luid.value: fixture.clock.date.addingTimeInterval(-61)
        ])
        fixture.rebuild()
        await fixture.drain()
        XCTAssertTrue(fixture.settings.movementAlertHysteresisLastEvents().isEmpty)
        fixture.alerts.alerts = ["movement": .movement(last: 1)]
        var record = fixture.record()
        record.movementCounter = 2
        await fixture.process(record, network: false, trigger: false)
        XCTAssertTrue(fixture.notifications.moves.isEmpty)
        XCTAssertFalse(fixture.settings.movementAlertHysteresisLastEvents().isEmpty)
        fixture.settings.movementAlertHysteresisMinutes = 0
        try XCTUnwrap(fixture.notifier.movementAlertHysteresisTimer).fire()
        await fixture.drain()
        XCTAssertTrue(fixture.settings.movementAlertHysteresisLastEvents().isEmpty)
        XCTAssertEqual(fixture.observer.types.last { $0.1.rawValue == "movement" }?.2, false)
        fixture.settings.movementAlertHysteresisMinutes = 1
        record.movementCounter = 3
        await fixture.process(record, network: false)
        fixture.alerts.enabledMovementIDs = []
        NotificationCenter.default.post(
            name: .RuuviServiceAlertDidChange, object: nil,
            userInfo: [
                RuuviServiceAlertDidChangeKey.type: AlertType.movement(last: 0),
                RuuviServiceAlertDidChangeKey.physicalSensor: record,
            ])
        await fixture.drain()
        XCTAssertTrue(fixture.settings.movementAlertHysteresisLastEvents().isEmpty)
        NotificationCenter.default.post(name: .RuuviServiceAlertDidChange, object: nil)
        NotificationCenter.default.post(
            name: .RuuviServiceAlertDidChange, object: nil,
            userInfo: [
                RuuviServiceAlertDidChangeKey.type: AlertType.connection,
                RuuviServiceAlertDidChangeKey.physicalSensor: record,
            ])
    }

    func testCloudConnectionAlertRequiresStaleSensorDataAndARecentSuccessfulCloudSync() async {
        let fixture = NotifierFixture()
        defer { fixture.close() }
        fixture.alerts.alerts = ["cloudConnection": .cloudConnection(unseenDuration: 60)]
        var record = fixture.record()
        record.date = fixture.clock.date.addingTimeInterval(-120)
        await fixture.process(record, network: true)
        XCTAssertEqual(fixture.observer.overall.first?.1, true)
        fixture.sync.setSyncDate(fixture.clock.date.addingTimeInterval(-180))
        await fixture.process(record, network: true)
        XCTAssertEqual(fixture.observer.overall.first?.1, false)
        fixture.sync.setSyncDate(fixture.clock.date)
        await fixture.process(record, network: true)
        XCTAssertEqual(fixture.observer.overall.first?.1, true)
        record.date = fixture.clock.date
        await fixture.process(record, network: true)
        XCTAssertEqual(fixture.observer.overall.first?.1, false)
        XCTAssertTrue(fixture.notifications.alerts.isEmpty)
    }

    func testInvalidCloudConnectionDelaysCannotCrashOrTriggerAndFractionalSecondsRemainPrecise() async {
        let fixture = NotifierFixture()
        defer { fixture.close() }
        var record = fixture.record()
        record.date = fixture.clock.date.addingTimeInterval(-0.75)
        for delay in [Double.nan, .infinity, -.infinity, -1, .greatestFiniteMagnitude] {
            fixture.alerts.alerts = ["cloudConnection": .cloudConnection(unseenDuration: delay)]
            await fixture.process(record, network: true)
            XCTAssertEqual(fixture.observer.overall.first?.1, false)
        }
        fixture.alerts.alerts = ["cloudConnection": .cloudConnection(unseenDuration: 0.9)]
        await fixture.process(record, network: true)
        XCTAssertEqual(fixture.observer.overall.first?.1, false)
        fixture.alerts.alerts = ["cloudConnection": .cloudConnection(unseenDuration: 0.5)]
        await fixture.process(record, network: true)
        XCTAssertEqual(fixture.observer.overall.first?.1, true)
    }
}
