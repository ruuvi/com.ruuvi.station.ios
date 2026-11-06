import Foundation
import RuuviCore
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class AlertStateServiceTests: XCTestCase {
    func testMutingAndUnmutingPreserveEachAlertConfigurationAndPersistItsDeadline() async {
        let fixture = AlertStateFixture()
        defer { fixture.cleanup() }
        let deadline = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 3600)
        for type in [AlertType.temperature(lower: 10, upper: 30), .connection, .cloudConnection(unseenDuration: 900)] {
            fixture.configure(type, muted: nil)
            fixture.service.muteAlert(
                for: type, till: deadline, snapshot: fixture.snapshot, physicalSensor: fixture.sensor)
            XCTAssertEqual(fixture.snapshot.getAlertConfig(for: type)?.mutedTill, deadline)
            XCTAssertEqual(fixture.measurements.alerts.mutedTill(type: type, for: fixture.sensor), deadline)
            XCTAssertEqual(fixture.snapshot.getAlertConfig(for: type)?.description, "Preserved description")
            fixture.service.unmuteAlert(for: type, snapshot: fixture.snapshot, physicalSensor: fixture.sensor)
            XCTAssertNil(fixture.snapshot.getAlertConfig(for: type)?.mutedTill)
            XCTAssertNil(fixture.measurements.alerts.mutedTill(type: type, for: fixture.sensor))
            XCTAssertEqual(fixture.snapshot.getAlertConfig(for: type)?.lowerBound, 10)
            XCTAssertEqual(fixture.snapshot.getAlertConfig(for: type)?.upperBound, 30)
        }
        await flushAppBindings()
    }

    func testExpiredMutesClearForMeasurementAndConnectionAlertsWhileFutureMutesRemain() {
        let fixture = AlertStateFixture()
        defer { fixture.cleanup() }
        let expired = Date().addingTimeInterval(-60)
        let future = Date().addingTimeInterval(3600)
        let temperature = AlertType.temperature(lower: 10, upper: 30)
        fixture.configure(temperature, muted: expired)
        fixture.configure(.connection, muted: expired)
        fixture.configure(.movement(last: 1), muted: future)
        fixture.service.reloadMutedTillStates(for: [fixture.snapshot])
        XCTAssertNil(fixture.snapshot.getAlertConfig(for: temperature)?.mutedTill)
        XCTAssertNil(fixture.snapshot.getAlertConfig(for: .connection)?.mutedTill)
        XCTAssertEqual(fixture.snapshot.getAlertConfig(for: .movement(last: 1))?.mutedTill, future)
        XCTAssertTrue(fixture.snapshot.getAlertConfig(for: temperature)?.isActive == true)
        XCTAssertEqual(fixture.snapshot.getAlertConfig(for: .connection)?.description, "Preserved description")
    }

    func testValidationDetectsMeasurementAndConnectionStateDrift() {
        let fixture = AlertStateFixture()
        defer { fixture.cleanup() }
        XCTAssertFalse(fixture.service.hasActiveAlerts(for: fixture.snapshot))
        let temperature = AlertType.temperature(lower: 10, upper: 30)
        fixture.configure(temperature, muted: nil)
        XCTAssertFalse(fixture.service.validateAlertState(for: fixture.snapshot, physicalSensor: fixture.sensor))
        fixture.measurements.alerts.register(type: temperature, ruuviTag: fixture.sensor)
        XCTAssertTrue(fixture.service.validateAlertState(for: fixture.snapshot, physicalSensor: fixture.sensor))
        fixture.configure(.connection, muted: nil)
        XCTAssertFalse(fixture.service.validateAlertState(for: fixture.snapshot, physicalSensor: fixture.sensor))
        fixture.measurements.alerts.register(type: .connection, ruuviTag: fixture.sensor)
        XCTAssertTrue(fixture.service.validateAlertState(for: fixture.snapshot, physicalSensor: fixture.sensor))
        XCTAssertTrue(fixture.service.hasActiveAlerts(for: fixture.snapshot))
        XCTAssertTrue(fixture.service.hasFiringAlerts(for: fixture.snapshot))
    }

    func testSharedSensorHiddenAlertsTurnOffWithoutChangingVisibleOrOwnerAlerts() async {
        let fixture = AlertStateFixture()
        defer { fixture.cleanup() }
        var sensor = fixture.sensor
        sensor.isOwner = false
        let temperature = AlertType.temperature(lower: 10, upper: 30)
        let pressure = AlertType.pressure(
            lower: 950, upper: 1050)
        for type in [temperature, pressure] {
            fixture.configure(type, muted: nil)
            fixture.measurements.alerts.register(type: type, ruuviTag: sensor)
        }
        fixture.snapshot.displayData.measurementVisibility = .init(
            usesDefaultOrder: false,
            availableVariants: [.init(type: .temperature), .init(type: .pressure)],
            visibleVariants: [.init(type: .pressure)])
        fixture.service.disableHiddenMeasurementAlerts(for: [fixture.snapshot], sensors: [sensor.any])
        await waitForAppState("shared hidden temperature disabled") {
            !fixture.measurements.alerts.isOn(type: temperature, for: sensor)
        }
        XCTAssertTrue(fixture.measurements.alerts.isOn(type: pressure, for: sensor))
        sensor.isOwner = true
        fixture.measurements.alerts.register(type: temperature, ruuviTag: sensor)
        fixture.service.disableHiddenMeasurementAlerts(for: [fixture.snapshot], sensors: [sensor.any])
        await flushAppBindings()
        XCTAssertTrue(fixture.measurements.alerts.isOn(type: temperature, for: sensor))
    }

    func testPushCapabilityRequiresAuthorizationAndAReachableSensorAndRefreshesOnActivation() async {
        let fixture = AlertStateFixture()
        defer { fixture.cleanup() }
        fixture.push.status = .notDetermined
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        await waitForAppState("push permission requested") { fixture.push.registrations == 1 }
        XCTAssertFalse(fixture.snapshot.capabilities.isPushNotificationsEnabled)
        fixture.push.status = .authorized
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        await waitForAppState("push enabled") { fixture.snapshot.capabilities.isPushNotificationsEnabled }
        XCTAssertFalse(fixture.snapshot.capabilities.isPushNotificationsAvailable)
        fixture.snapshot.connectionData.isConnected = true
        fixture.service.updateSnapshot(fixture.snapshot)
        await waitForAppState("connected push available") { fixture.snapshot.capabilities.isPushNotificationsAvailable }
        fixture.push.status = .denied
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        await waitForAppState("push permission revoked") { !fixture.snapshot.capabilities.isPushNotificationsEnabled }
        XCTAssertFalse(fixture.snapshot.capabilities.isPushNotificationsAvailable)
    }
}

@MainActor private final class AlertStateFixture {
    let measurements = MeasurementFixture()
    let notifier = CoordinatorNotifierSpy()
    let push = AlertPushStatusSpy()
    let service: RuuviTagAlertService
    var sensor: RuuviTagSensorStruct { measurements.sensor }
    var snapshot: RuuviTagCardSnapshot { measurements.snapshot }
    init() {
        service = RuuviTagAlertService(
            alertService: measurements.alerts, alertHandler: notifier,
            settings: measurements.settings, pushNotificationsManager: push)
        service.updateSnapshot(measurements.snapshot)
    }
    func configure(_ type: AlertType, muted: Date?) {
        snapshot.updateAlertConfig(
            for: type,
            config: .init(
                type: type.toMeasurementType(), alertType: type,
                isActive: true, isFiring: true, mutedTill: muted, lowerBound: 10, upperBound: 30,
                description: "Preserved description", unseenDuration: 900))
    }
    func cleanup() { service.stopObservingAlerts(); service.updateSnapshots([]); measurements.cleanup() }
}

private final class AlertPushStatusSpy: RuuviCorePN {
    var pnTokenData: Data?
    var fcmToken: String?
    var fcmTokenId: Int?
    var fcmTokenLastRefreshed: Date?
    var status: PNAuthorizationStatus = .denied
    var registrations = 0
    func registerForRemoteNotifications() { registrations += 1 }
    func getRemoteNotificationsAuthorizationStatus(completion: @escaping (PNAuthorizationStatus) -> Void) {
        completion(status)
    }
}
