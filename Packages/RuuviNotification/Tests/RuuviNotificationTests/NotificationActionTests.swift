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

@MainActor final class NotificationActionTests: XCTestCase {
    func testSetupRegistersBothCategoriesAndRepeatedSetupDoesNotDuplicateObservers() {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        for _ in 0..<2 { fixture.notifications.setup(disableTitle: "Disable", muteTitle: "Mute", output: nil) }
        XCTAssertTrue(fixture.center.delegate === fixture.notifications)
        XCTAssertEqual(fixture.center.categories.count, 2)
        for category in fixture.center.categories {
            XCTAssertEqual(category.actions.map(\.title), ["Mute", "Disable"])
            XCTAssertEqual(
                category.actions.map(\.identifier), [category.identifier + ".mute", category.identifier + ".disable"])
            XCTAssertEqual(category.options, .customDismissAction)
        }
        for type in AlertType.allCases {
            fixture.alerts.register(type: type, ruuviTag: fixture.sensor)
            let previous = fixture.center.pendingRemovals.count
            fixture.alerts.unregister(type: type, ruuviTag: fixture.sensor)
            switch type {
            case .movement, .connection, .cloudConnection:
                XCTAssertEqual(fixture.center.pendingRemovals.count, previous)
            default:
                XCTAssertEqual(fixture.center.pendingRemovals.count, previous + 1)
                XCTAssertEqual(fixture.center.pendingRemovals.last, fixture.uuid + type.rawValue)
                XCTAssertEqual(fixture.center.deliveredRemovals.last, fixture.uuid + type.rawValue)
            }
        }
        let previous = fixture.center.pendingRemovals.count
        NotificationCenter.default.post(name: .RuuviServiceAlertDidChange, object: nil)
        NotificationCenter.default.post(name: .RuuviServiceAlertDidChange, object: nil, userInfo: ["wrong": "payload"])
        XCTAssertEqual(fixture.center.pendingRemovals.count, previous)
    }

    func testForegroundPresentationRespectsAlertCategoryAndLimitSetting() {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        let quiet: UNNotificationPresentationOptions = [.list, .badge]
        let full: UNNotificationPresentationOptions = [.banner, .list, .badge, .sound]
        for limited in [false, true] {
            fixture.settings.limitAlertNotificationsEnabled = limited
            for category in ["com.ruuvi.station.alerts.lh", "com.ruuvi.station.alerts.blast"] {
                XCTAssertEqual(fixture.notifications.presentationOptions(for: category), limited ? full : quiet)
            }
            XCTAssertEqual(fixture.notifications.presentationOptions(for: "push"), full)
        }
    }

    func testMuteAndDisableActionsForEveryAlertUseSavedIdentityAndCompleteOnce() async {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        let output = NotificationOutputSpy()
        fixture.notifications.setup(disableTitle: "Disable", muteTitle: "Mute", output: output)
        for type in AlertType.allCases {
            let category: String
            switch type {
            case .connection, .movement: category = "com.ruuvi.station.alerts.blast"
            default: category = "com.ruuvi.station.alerts.lh"
            }
            fixture.alerts.register(type: type, ruuviTag: fixture.sensor)
            let userInfo = [category + ".uuid": fixture.uuid, category + ".type": type.rawValue]
            for action in ["mute", "disable"] {
                let completed = expectation(description: type.rawValue + action)
                fixture.notifications.handle(action: category + "." + action, userInfo: userInfo) {
                    completed.fulfill()
                }
                await fulfillment(of: [completed], timeout: 3)
                if action == "mute" {
                    XCTAssertEqual(
                        fixture.alerts.mutedTill(type: type, for: fixture.sensor), fixture.date.addingTimeInterval(3600)
                    )
                    XCTAssertTrue(fixture.alerts.isOn(type: type, for: fixture.sensor))
                } else {
                    XCTAssertFalse(fixture.alerts.isOn(type: type, for: fixture.sensor))
                }
            }
        }
        XCTAssertEqual(output.identifiers.count, AlertType.allCases.count * 2)
        XCTAssertTrue(output.identifiers.allSatisfy { $0 == fixture.uuid })
        XCTAssertTrue(fixture.reads.allSatisfy { $0 == fixture.sensor.macId!.value })
    }

    func testDisableKeepsConfiguredThresholdValues() async {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        let type = AlertType.temperature(lower: -10, upper: 42)
        fixture.alerts.register(type: type, ruuviTag: fixture.sensor)
        let completed = expectation(description: "Disabled")
        fixture.notifications.handle(
            action: "com.ruuvi.station.alerts.lh.disable",
            userInfo: [
                "com.ruuvi.station.alerts.lh.uuid": fixture.uuid,
                "com.ruuvi.station.alerts.lh.type": type.rawValue,
            ]
        ) { completed.fulfill() }
        await fulfillment(of: [completed], timeout: 3)
        XCTAssertFalse(fixture.alerts.isOn(type: type, for: fixture.sensor))
        XCTAssertEqual(fixture.alerts.lowerCelsius(for: fixture.sensor), -10)
        XCTAssertEqual(fixture.alerts.upperCelsius(for: fixture.sensor), 42)
    }

    func testMissingSensorAndAlreadyDisabledAlertStillCompleteActions() async {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        for failedRead in [false, true] {
            fixture.failRead = failedRead
            let done = expectation(description: "Action completion")
            fixture.notifications.handle(
                action: "com.ruuvi.station.alerts.lh.disable",
                userInfo: [
                    "com.ruuvi.station.alerts.lh.uuid": fixture.uuid,
                    "com.ruuvi.station.alerts.lh.type": "temperature",
                ]
            ) { done.fulfill() }
            await fulfillment(of: [done], timeout: 3)
        }
        XCTAssertTrue(fixture.cloud.alerts.isEmpty)
    }

    func testPushTapUnknownActionAndMalformedPayloadAlwaysComplete() {
        let fixture = LocalNotificationFixture()
        defer { fixture.clean() }
        let output = NotificationOutputSpy()
        fixture.notifications.setup(disableTitle: "Disable", muteTitle: "Mute", output: output)
        let payloads: [[AnyHashable: Any]] = [
            [:], ["id": "AA:BB:CC:DD:EE:FF"],
            ["com.ruuvi.station.alerts.lh.uuid": fixture.uuid, "com.ruuvi.station.alerts.lh.type": "temperature"],
            ["com.ruuvi.station.alerts.blast.uuid": fixture.uuid, "com.ruuvi.station.alerts.blast.type": "unknown"],
            ["com.ruuvi.station.alerts.lh.uuid": 12, "com.ruuvi.station.alerts.lh.type": "temperature"],
        ]
        var completions = 0
        for payload in payloads {
            fixture.notifications.handle(action: UNNotificationDefaultActionIdentifier, userInfo: payload) {
                completions += 1
            }
        }
        XCTAssertEqual(completions, payloads.count)
        XCTAssertEqual(output.identifiers, ["AA:BB:CC:DD:EE:FF", fixture.uuid, fixture.uuid])
        XCTAssertTrue(fixture.reads.isEmpty)
        XCTAssertTrue(fixture.cloud.alerts.isEmpty)
    }
}
