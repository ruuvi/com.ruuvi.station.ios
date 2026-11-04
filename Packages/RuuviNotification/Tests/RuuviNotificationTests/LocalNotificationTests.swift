import Foundation
import RuuviLocal
import RuuviOntology
import RuuviService
@testable import RuuviNotification
import UserNotifications
import XCTest
#if SWIFT_PACKAGE
    @testable import RuuviNotificationLocal
    import RuuviServiceAlert
#endif

@MainActor final class LocalNotificationTests: XCTestCase {
    func testAllThresholdNotificationsUseSensorIdentityDescriptionAndIndependentIdentifiers() async throws {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        let service = fixture.alerts
        let sensor = fixture.sensor
        let descriptions: [(String, (String?) -> Void)] = [
            ("temperature", { service.setTemperature(description: $0, ruuviTag: sensor) }),
            ("relativeHumidity", { service.setRelativeHumidity(description: $0, ruuviTag: sensor) }),
            ("absoluteHumidity", { service.setHumidity(description: $0, for: sensor) }),
            ("dewPoint", { service.setDewPoint(description: $0, ruuviTag: sensor) }),
            ("pressure", { service.setPressure(description: $0, ruuviTag: sensor) }),
            ("signal", { service.setSignal(description: $0, ruuviTag: sensor) }),
            ("batteryVoltage", { service.setBatteryVoltage(description: $0, ruuviTag: sensor) }),
            ("aqi", { service.setAQI(description: $0, ruuviTag: sensor) }),
            ("carbonDioxide", { service.setCarbonDioxide(description: $0, ruuviTag: sensor) }),
            ("pMatter1", { service.setPM1(description: $0, ruuviTag: sensor) }),
            ("pMatter25", { service.setPM25(description: $0, ruuviTag: sensor) }),
            ("pMatter4", { service.setPM4(description: $0, ruuviTag: sensor) }),
            ("pMatter10", { service.setPM10(description: $0, ruuviTag: sensor) }),
            ("voc", { service.setVOC(description: $0, ruuviTag: sensor) }),
            ("nox", { service.setNOX(description: $0, ruuviTag: sensor) }),
            ("soundInstant", { service.setSoundInstant(description: $0, ruuviTag: sensor) }),
            ("soundAverage", { service.setSoundAverage(description: $0, ruuviTag: sensor) }),
            ("soundPeak", { service.setSoundPeak(description: $0, ruuviTag: sensor) }),
            ("luminosity", { service.setLuminosity(description: $0, ruuviTag: sensor) }),
        ]
        for (rawType, setDescription) in descriptions {
            let type = try XCTUnwrap(AlertType.alertType(from: rawType))
            service.register(type: type, ruuviTag: sensor)
            setDescription("Description: " + rawType)
            let delivered = expectation(description: rawType)
            fixture.center.onBadge = { delivered.fulfill() }
            fixture.notifications.notify(.high, type, for: fixture.uuid, title: rawType + " high")
            await fulfillment(of: [delivered], timeout: 3)
            let request = try XCTUnwrap(fixture.center.requests.last)
            XCTAssertEqual(request.identifier, fixture.uuid + rawType)
            XCTAssertEqual(request.content.title, rawType + " high")
            XCTAssertEqual(request.content.subtitle, sensor.name)
            XCTAssertEqual(request.content.body, "Description: " + rawType)
            XCTAssertEqual(request.content.sound, .default)
            XCTAssertEqual(request.content.categoryIdentifier, "com.ruuvi.station.alerts.lh")
            XCTAssertEqual(request.content.userInfo["com.ruuvi.station.alerts.lh.uuid"] as? String, fixture.uuid)
            XCTAssertEqual((request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval, 0.1)
            XCTAssertEqual(service.triggered(for: sensor, of: type), true)
            let timestamp = try XCTUnwrap(service.triggeredAt(for: sensor, of: type))
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            XCTAssertEqual(formatter.date(from: timestamp), fixture.date)
        }
        XCTAssertEqual(fixture.center.requests.count, descriptions.count)
        XCTAssertEqual(fixture.center.badges, Array(1...descriptions.count))
        XCTAssertTrue(fixture.reads.allSatisfy { $0 == sensor.macId?.value })
    }

    func testConnectionMovementAndCustomSound() async throws {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        fixture.settings.alertSound = .ruuviSpeak
        fixture.alerts.setConnection(description: "Connection description", for: fixture.sensor)
        fixture.alerts.setMovement(description: "Movement description", ruuviTag: fixture.sensor)
        let delivered = expectation(description: "Three blast notifications")
        delivered.expectedFulfillmentCount = 3
        fixture.center.onBadge = { delivered.fulfill() }
        fixture.notifications.showDidConnect(uuid: fixture.uuid, title: "Connected")
        fixture.notifications.showDidDisconnect(uuid: fixture.uuid, title: "Disconnected")
        fixture.notifications.notifyDidMove(for: fixture.uuid, counter: 7, title: "Moved")
        await fulfillment(of: [delivered], timeout: 3)
        XCTAssertEqual(fixture.center.requests.map(\.content.title), ["Connected", "Disconnected", "Moved"])
        XCTAssertEqual(
            fixture.center.requests.map(\.content.body),
            ["Connection description", "Connection description", "Movement description"])
        XCTAssertEqual(Set(fixture.center.requests.map(\.identifier)).count, 3)
        for request in fixture.center.requests {
            XCTAssertEqual(request.content.categoryIdentifier, "com.ruuvi.station.alerts.blast")
            XCTAssertEqual(request.content.sound, UNNotificationSound(named: .init(rawValue: "ruuvi_speak.caf")))
        }
    }

    func testActiveMuteSuppressesAndExpiredMuteAllowsAlert() async throws {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        let type = AlertType.temperature(lower: 0, upper: 10)
        fixture.alerts.mute(type: type, for: fixture.sensor, till: fixture.date.addingTimeInterval(60))
        let unexpected = expectation(description: "Muted notification")
        unexpected.isInverted = true
        fixture.center.onAdd = { unexpected.fulfill() }
        fixture.notifications.notify(.low, type, for: fixture.uuid, title: "Muted")
        await fulfillment(of: [unexpected], timeout: 0.05)
        XCTAssertTrue(fixture.center.badges.isEmpty)
        fixture.date.addTimeInterval(61)
        fixture.center.onAdd = nil
        let delivered = expectation(description: "Mute expired")
        fixture.center.onBadge = { delivered.fulfill() }
        fixture.notifications.notify(.low, type, for: fixture.uuid, title: "Allowed")
        await fulfillment(of: [delivered], timeout: 3)
        XCTAssertEqual(fixture.center.requests.map(\.content.title), ["Allowed"])
    }

    func testThrottleAcceptsFractionalAndWholeSecondUTCAndAllowsAtIntervalBoundary() async {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        fixture.settings.limitAlertNotificationsEnabled = true
        let type = AlertType.temperature(lower: 0, upper: 10)
        let formatter = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [
            .withInternetDateTime, [.withInternetDateTime, .withFractionalSeconds],
        ] {
            formatter.formatOptions = options
            fixture.alerts.trigger(
                type: type, trigerred: true,
                trigerredAt: formatter.string(from: fixture.date), for: fixture.sensor)
            let unexpected = expectation(description: "Throttled notification")
            unexpected.isInverted = true
            fixture.center.onAdd = { unexpected.fulfill() }
            fixture.notifications.notify(.high, type, for: fixture.uuid, title: "Throttled")
            await fulfillment(of: [unexpected], timeout: 0.05)
        }
        fixture.center.onAdd = nil
        fixture.date.addTimeInterval(3600)
        let delivered = expectation(description: "At throttle boundary")
        fixture.center.onBadge = { delivered.fulfill() }
        fixture.notifications.notify(.high, type, for: fixture.uuid, title: "Allowed")
        await fulfillment(of: [delivered], timeout: 3)
        XCTAssertEqual(fixture.center.requests.count, 1)
    }

    func testDeliveryFailureDoesNotConsumeBadgeOrThrottleRetry() async {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        fixture.settings.limitAlertNotificationsEnabled = true
        let type = AlertType.temperature(lower: 0, upper: 10)
        fixture.center.failAdd = true
        let failed = expectation(description: "Scheduling failed")
        fixture.center.onAdd = { failed.fulfill() }
        fixture.notifications.notify(.high, type, for: fixture.uuid, title: "Failed")
        await fulfillment(of: [failed], timeout: 3)
        XCTAssertEqual(fixture.settings.notificationsBadgeCount(), 0)
        XCTAssertNil(fixture.alerts.triggeredAt(for: fixture.sensor, of: type))
        fixture.center.failAdd = false
        fixture.center.onAdd = nil
        let delivered = expectation(description: "Retry delivered")
        fixture.center.onBadge = { delivered.fulfill() }
        fixture.notifications.notify(.high, type, for: fixture.uuid, title: "Retry")
        await fulfillment(of: [delivered], timeout: 3)
        XCTAssertEqual(fixture.center.badges, [1])
    }

    func testMissingSensorCannotScheduleOrIncrementBadge() async {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        fixture.failRead = true
        let unexpected = expectation(description: "Missing sensor delivery")
        unexpected.isInverted = true
        fixture.center.onAdd = { unexpected.fulfill() }
        fixture.notifications.showDidConnect(uuid: fixture.uuid, title: "No sensor")
        await fulfillment(of: [unexpected], timeout: 0.05)
        XCTAssertEqual(fixture.settings.notificationsBadgeCount(), 0)
        XCTAssertTrue(fixture.center.badges.isEmpty)
    }

    func testRapidReadingsAreSerializedAndThrottledAfterFirstSuccessfulDelivery() async {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        fixture.settings.limitAlertNotificationsEnabled = true
        let type = AlertType.temperature(lower: 0, upper: 10)
        let gate = AsyncStream<Void>.makeStream()
        fixture.center.beforeAdd = { for await _ in gate.stream { break } }
        let delivered = expectation(description: "Only first reading delivers")
        fixture.center.onBadge = { delivered.fulfill() }
        for _ in 0..<5 { fixture.notifications.notify(.high, type, for: fixture.uuid, title: "Burst") }
        gate.continuation.finish()
        await fulfillment(of: [delivered], timeout: 3)
        let unexpected = expectation(description: "No repeat")
        unexpected.isInverted = true
        fixture.center.onAdd = { unexpected.fulfill() }
        await fulfillment(of: [unexpected], timeout: 0.05)
        XCTAssertEqual(fixture.center.requests.count, 1)
        XCTAssertEqual(fixture.center.badges, [1])
    }

    func testMalformedTriggerTimestampDoesNotMuteForeverAndBadgesCannotOverflow() async {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        fixture.settings.limitAlertNotificationsEnabled = true
        fixture.settings.setNotificationsBadgeCount(value: Int.max)
        let type = AlertType.cloudConnection(unseenDuration: 300)
        fixture.alerts.trigger(type: type, trigerred: true, trigerredAt: "invalid", for: fixture.sensor)
        let delivered = expectation(description: "Invalid trigger ignored")
        fixture.center.onBadge = { delivered.fulfill() }
        fixture.notifications.notify(.high, type, for: fixture.sensor.macId!.value, title: "Offline")
        await fulfillment(of: [delivered], timeout: 3)
        XCTAssertEqual(fixture.center.badges, [Int.max])
        XCTAssertEqual(fixture.center.requests.first?.content.body, "")
    }
}
