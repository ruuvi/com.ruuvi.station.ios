import Foundation
import RuuviLocalization
@testable import RuuviNotificationRemote
import UserNotifications
import XCTest

final class RemoteNotificationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var service: RuuviRemoteNotificationService!

    override func setUp() {
        super.setUp()
        suite = "RemoteNotificationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.set("en", forKey: RuuviRemoteNotificationService.languageKey)
        service = RuuviRemoteNotificationService(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        service = nil
        defaults = nil
        super.tearDown()
    }

    func testEveryNumericAlertUsesCorrectMeasurementAndThresholdInBothDirections() throws {
        let measurements = [
            "temperature": "Temperature", "humidity": "Air humidity", "pressure": "Air pressure",
            "signal": "Signal strength", "aqi": "Air quality", "co2": "CO₂", "pm1": "PM1.0",
            "pm25": "PM2.5", "pm40": "PM4.0", "pm10": "PM10.0", "voc": "VOC index",
            "nox": "NOx index", "luminosity": "Luminosity", "soundInstant": "Current sound level",
            "soundAverage": "Sound Average", "soundPeak": "Sound Peak",
        ]
        for (type, name) in measurements {
            for (trigger, comparison) in [("under", "below"), ("OVER", "above")] {
                let request = request(type: type.uppercased(), trigger: trigger)
                let content = try deliver(request)
                XCTAssertEqual(content.title, "\(name) is \(comparison) 42.5", type)
                XCTAssertEqual(content.subtitle, "Bedroom is outside the configured range", type)
                XCTAssertEqual(content.body, "Bedroom 🌡️", type)
                XCTAssertEqual(request.content.title, "Server title", "Formatting must not mutate the input")
                XCTAssertEqual(content.categoryIdentifier, "sensor-alert")
                XCTAssertEqual(content.threadIdentifier, "sensor-123")
                XCTAssertEqual(content.sound, .default)
                XCTAssertEqual(content.userInfo["extra"] as? String, "preserved")
            }
        }
    }

    func testMovementAndOfflineAlerts() throws {
        for trigger in ["over", "under"] {
            let movement = try deliver(request(type: "movement", trigger: trigger))
            XCTAssertEqual(
                movement.title, RuuviLocalization.LocalNotificationsManager.DidMove.title(Locale(identifier: "en")))
        }
        let offline = try deliver(request(type: "offline", trigger: "over"))
        XCTAssertEqual(offline.title, "Sensor has been offline over 42.5 minutes")
        assertServerContent(try deliver(request(type: "offline", trigger: "under")))
    }

    func testUnknownTypesAndIncompletePayloadsPreserveServerMessage() throws {
        assertServerContent(try deliver(request(type: "future-sensor-metric", trigger: "over")))
        assertServerContent(try deliver(request(type: "temperature", trigger: "invalid")))
        for key in ["name", "alertType", "triggerType", "thresholdValue", "alertData"] {
            for invalid: Any? in [nil, 123] {
                let original = request()
                let content = try XCTUnwrap(original.content.mutableCopy() as? UNMutableNotificationContent)
                content.userInfo[key] = invalid
                assertServerContent(try deliver(UNNotificationRequest(identifier: key, content: content, trigger: nil)))
            }
        }
    }

    func testBothJSONAndStringFalseKeepServerFormatting() throws {
        for flag: Any in [false, "false", "FALSE"] {
            assertServerContent(try deliver(request(formatLocally: flag)))
        }
        for flag: Any in [true, "true"] {
            XCTAssertEqual(try deliver(request(formatLocally: flag)).title, "Temperature is above 42.5")
        }
    }

    func testExpiryCannotDeliverTwiceOrIncrementBadgeAgain() {
        defaults.set(7, forKey: RuuviRemoteNotificationService.badgeKey)
        var callbacks = 0
        service.didReceive(request()) { content in
            callbacks += 1
            XCTAssertEqual(content.badge, 8)
        }
        service.serviceExtensionTimeWillExpire()
        service.serviceExtensionTimeWillExpire()
        XCTAssertEqual(callbacks, 1)
        XCTAssertEqual(defaults.integer(forKey: RuuviRemoteNotificationService.badgeKey), 8)
    }

    func testSequentialAndReentrantDeliveryHaveIndependentContentAndBadges() throws {
        var titles: [String] = []
        service.didReceive(request()) { [self] content in
            titles.append(content.title)
            XCTAssertEqual(content.badge, 1)
            service.didReceive(request(type: "co2")) { second in
                titles.append(second.title)
                XCTAssertEqual(second.badge, 2)
            }
        }
        XCTAssertEqual(titles, ["Temperature is above 42.5", "CO₂ is above 42.5"])
        XCTAssertEqual(try deliver(request()).badge, 3)
    }

    func testBadgeHandlesMissingNegativeAndMaximumValues() throws {
        XCTAssertEqual(try deliver(request()).badge, 1)
        defaults.set(-30, forKey: RuuviRemoteNotificationService.badgeKey)
        XCTAssertEqual(try deliver(request()).badge, 1)
        defaults.set(Int.max, forKey: RuuviRemoteNotificationService.badgeKey)
        XCTAssertEqual(try deliver(request()).badge, NSNumber(value: Int.max))
    }

    func testLanguagePreferenceAndMissingDefaults() throws {
        defaults.set("fi", forKey: RuuviRemoteNotificationService.languageKey)
        XCTAssertEqual(
            try deliver(request()).title,
            RuuviLocalization.alertNotificationTemperatureHighThreshold("42.5", Locale(identifier: "fi")))
        service = RuuviRemoteNotificationService(defaults: nil)
        let content = try deliver(request())
        XCTAssertEqual(content.title, RuuviLocalization.alertNotificationTemperatureHighThreshold("42.5", .current))
        XCTAssertEqual(content.badge, 1)
        // Expiry before receiving a request must be harmless, including the production initializer.
        RuuviRemoteNotificationService().serviceExtensionTimeWillExpire()
    }

    private func deliver(_ request: UNNotificationRequest) throws -> UNNotificationContent {
        var result: UNNotificationContent?
        service.didReceive(request) { result = $0 }
        return try XCTUnwrap(result)
    }

    private func assertServerContent(
        _ content: UNNotificationContent, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(content.title, "Server title", file: file, line: line)
        XCTAssertEqual(content.subtitle, "Server subtitle", file: file, line: line)
        XCTAssertEqual(content.body, "Server body", file: file, line: line)
        XCTAssertNotNil(content.badge, file: file, line: line)
    }

    private func request(type: String = "temperature", trigger: String = "over", formatLocally: Any? = nil)
        -> UNNotificationRequest
    {
        let content = UNMutableNotificationContent()
        content.title = "Server title"
        content.subtitle = "Server subtitle"
        content.body = "Server body"
        content.categoryIdentifier = "sensor-alert"
        content.threadIdentifier = "sensor-123"
        content.sound = .default
        content.userInfo = [
            "name": "Bedroom 🌡️", "alertType": type, "triggerType": trigger,
            "thresholdValue": "42.5", "alertData": "Bedroom is outside the configured range",
            "extra": "preserved",
        ]
        content.userInfo["showLocallyFormatted"] = formatLocally
        return UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    }
}
