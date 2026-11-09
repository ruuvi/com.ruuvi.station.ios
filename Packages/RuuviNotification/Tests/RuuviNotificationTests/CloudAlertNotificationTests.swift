#if canImport(RuuviNotificationLocal)
@testable import RuuviNotificationLocal
#else
@testable import RuuviNotification
#endif
import Future
import RuuviCloud
import RuuviOntology
import RuuviStorage
import UserNotifications
import XCTest

final class CloudAlertNotificationTests: XCTestCase {
    func testRegistersOnlyTheLocalizedCloudDisableAction() {
        let category = CloudAlertNotification.category(disableTitle: "Disable this alarm")
        XCTAssertEqual(category.identifier, "com.ruuvi.station.alerts.cloud")
        XCTAssertEqual(category.actions.count, 1)
        XCTAssertEqual(category.actions.first?.identifier, "com.ruuvi.station.alerts.cloud.disable")
        XCTAssertEqual(category.actions.first?.title, "Disable this alarm")
        XCTAssertEqual(category.actions.first?.options, [])
    }

    func testMapsCloudAlertTypesIncludingHumidityParticulatesAndOffline() throws {
        let types = [
            "temperature": "temperature", "humidity": "relativeHumidity",
            "humidityAbsolute": "absoluteHumidity", "dewPoint": "dewPoint",
            "pressure": "pressure", "signal": "signal", "battery": "batteryVoltage",
            "movement": "movement", "offline": "cloudConnection", "aqi": "aqi",
            "co2": "carbonDioxide", "pm10": "pMatter1", "pm25": "pMatter25",
            "pm40": "pMatter4", "pm100": "pMatter10", "voc": "voc", "nox": "nox",
            "soundInstant": "soundInstant", "soundAverage": "soundAverage",
            "soundPeak": "soundPeak", "luminosity": "luminosity",
        ]
        for (cloudType, localType) in types {
            var payload = CloudActionFixture.payload
            payload["alertType"] = cloudType
            payload["id"] = "aa:bb:cc:dd:ee:ff"
            let notification = try XCTUnwrap(CloudAlertNotification(userInfo: payload))
            XCTAssertEqual(notification.alertType.rawValue, localType, cloudType)
            XCTAssertEqual(notification.cloudAlertType.rawValue, cloudType)
            XCTAssertEqual(notification.sensorID, "AA:BB:CC:DD:EE:FF")
        }
    }

    func testRejectsIncompleteOrUnknownPayloads() {
        for key in ["id", "alertType", "email"] {
            var payload = CloudActionFixture.payload
            payload.removeValue(forKey: key)
            XCTAssertNil(CloudAlertNotification(userInfo: payload), key)
        }
        let invalidValues = [
            ("id", "invalid"), ("id", "AA:BB:CC:DD:EE:FF\n"),
            ("alertType", "future-alert"), ("alertType", "sound"), ("email", " "),
        ]
        for (key, value) in invalidValues {
            var payload = CloudActionFixture.payload
            payload[key] = value
            XCTAssertNil(CloudAlertNotification(userInfo: payload), key)
        }
    }

    func testSignedOutOrDifferentAccountCannotDisableAnAlert() {
        let sessions: [CloudAlertNotificationHandler.Session?] = [
            nil, .init(email: "other@example.com", apiKey: "other-session"),
            .init(email: "owner@example.com", apiKey: ""),
            .init(email: "owner@example.com", apiKey: " \n"),
        ]
        for session in sessions {
            let fixture = CloudActionFixture()
            fixture.session = session
            var completions = 0
            fixture.handler.handle(userInfo: CloudActionFixture.payload) { completions += 1 }
            XCTAssertEqual(completions, 1)
            XCTAssertTrue(fixture.readIDs.isEmpty)
            XCTAssertTrue(fixture.disabledTypes.isEmpty)
        }
    }

    func testMalformedActionCompletesWithoutReadingStorage() {
        let fixture = CloudActionFixture()
        var completions = 0
        fixture.handler.handle(userInfo: [:]) { completions += 1 }
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(fixture.readIDs.isEmpty)
    }

    func testWaitsForCloudDeliveryBeforeCompletingTheResponse() {
        let fixture = CloudActionFixture()
        fixture.session = .init(email: "OWNER@example.com", apiKey: "session")
        let started = expectation(description: "Cloud disable started")
        let completed = expectation(description: "Notification completed")
        fixture.onDisable = { started.fulfill() }
        var completions = 0
        fixture.handler.handle(userInfo: CloudActionFixture.payload) {
            completions += 1
            completed.fulfill()
        }
        XCTAssertEqual(fixture.readIDs, ["AA:BB:CC:DD:EE:FF"])
        fixture.storage.succeed(value: fixture.sensor())
        wait(for: [started], timeout: 2)
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(fixture.disabledTypes, [.temperature])
        XCTAssertEqual(fixture.disabledMACs, ["AA:BB:CC:DD:EE:FF"])
        XCTAssertTrue(fixture.localDisabledTypes.isEmpty)
        fixture.delivery.succeed(value: ())
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(fixture.localDisabledTypes, [.temperature(lower: 0, upper: 0)])
    }

    func testDisablesTheExactCloudTypeWithoutRequiringLocalAlertBounds() {
        let types: [RuuviCloudAlertType] = [
            .humidity, .humidityAbsolute, .movement, .offline,
            .soundInstant, .soundAverage, .soundPeak,
        ]
        for type in types {
            let fixture = CloudActionFixture()
            let started = expectation(description: "Disable \(type.rawValue)")
            let completed = expectation(description: "Finished \(type.rawValue)")
            fixture.onDisable = { started.fulfill() }
            var payload = CloudActionFixture.payload
            payload["alertType"] = type.rawValue
            fixture.handler.handle(userInfo: payload) { completed.fulfill() }
            fixture.storage.succeed(value: fixture.sensor())
            wait(for: [started], timeout: 2)
            XCTAssertEqual(fixture.disabledTypes, [type])
            fixture.delivery.succeed(value: ())
            wait(for: [completed], timeout: 2)
        }
    }

    func testAccountChangeDuringStorageReadCancelsTheAction() {
        let fixture = CloudActionFixture()
        let completed = expectation(description: "Cancelled action completed")
        fixture.handler.handle(userInfo: CloudActionFixture.payload) { completed.fulfill() }
        // Even signing back into the same email must not reuse an earlier session.
        fixture.session = .init(email: "owner@example.com", apiKey: "new-session")
        fixture.storage.succeed(value: fixture.sensor())
        wait(for: [completed], timeout: 2)
        XCTAssertTrue(fixture.disabledTypes.isEmpty)
    }

    func testLocalOrMismatchedSensorCannotBeDisabled() {
        for sensor in [
            CloudActionFixture().sensor(isCloud: false),
            CloudActionFixture().sensor(mac: "11:22:33:44:55:66"),
        ] {
            let fixture = CloudActionFixture()
            let completed = expectation(description: "Rejected sensor completed")
            fixture.handler.handle(userInfo: CloudActionFixture.payload) { completed.fulfill() }
            fixture.storage.succeed(value: sensor)
            wait(for: [completed], timeout: 2)
            XCTAssertTrue(fixture.disabledTypes.isEmpty)
        }
    }

    func testMissingSensorCompletesWithoutSendingACloudRequest() {
        let fixture = CloudActionFixture()
        let completed = expectation(description: "Missing sensor completed")
        fixture.handler.handle(userInfo: CloudActionFixture.payload) { completed.fulfill() }
        fixture.storage.fail(error: .ruuviPersistence(.failedToFindRuuviTag))
        wait(for: [completed], timeout: 2)
        XCTAssertTrue(fixture.disabledTypes.isEmpty)
    }

    func testCloudFailureAlsoCompletesTheNotificationResponse() {
        let fixture = CloudActionFixture()
        let started = expectation(description: "Cloud request reached")
        let completed = expectation(description: "Failed request completed")
        fixture.onDisable = { started.fulfill() }
        var completions = 0
        fixture.handler.handle(userInfo: CloudActionFixture.payload) {
            completions += 1
            completed.fulfill()
        }
        fixture.storage.succeed(value: fixture.sensor())
        wait(for: [started], timeout: 2)
        fixture.delivery.fail(error: .notAuthorized)
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(fixture.localDisabledTypes.isEmpty)
    }

    func testAccountChangeDuringCloudRequestDoesNotChangeNewAccountsLocalAlerts() {
        let fixture = CloudActionFixture()
        let started = expectation(description: "Cloud request started")
        let completed = expectation(description: "Old session action completed")
        fixture.onDisable = { started.fulfill() }
        fixture.handler.handle(userInfo: CloudActionFixture.payload) { completed.fulfill() }
        fixture.storage.succeed(value: fixture.sensor())
        wait(for: [started], timeout: 2)
        fixture.session = .init(email: "other@example.com", apiKey: "new-session")
        fixture.delivery.succeed(value: ())
        wait(for: [completed], timeout: 2)
        XCTAssertTrue(fixture.localDisabledTypes.isEmpty)
    }
}

private final class CloudActionFixture {
    static let payload: [AnyHashable: Any] = [
        "id": "AA:BB:CC:DD:EE:FF", "alertType": "temperature", "email": "owner@example.com",
    ]
    var session: CloudAlertNotificationHandler.Session? = .init(email: "owner@example.com", apiKey: "session")
    let storage = Promise<AnyRuuviTagSensor, RuuviStorageError>()
    let delivery = Promise<Void, RuuviCloudError>()
    var readIDs = [String]()
    var disabledTypes = [RuuviCloudAlertType]()
    var disabledMACs = [String]()
    var localDisabledTypes = [AlertType]()
    var onDisable: (() -> Void)?
    lazy var handler = CloudAlertNotificationHandler(
        currentSession: { [unowned self] in session },
        readSensor: { [unowned self] id in
            readIDs.append(id)
            return storage.future
        },
        disableAlert: { [unowned self] type, macId in
            disabledTypes.append(type)
            disabledMACs.append(macId.value)
            onDisable?()
            return delivery.future
        },
        disableLocalAlert: { [unowned self] type, _ in localDisabledTypes.append(type) }
    )

    func sensor(isCloud: Bool = true, mac: String = "AA:BB:CC:DD:EE:FF") -> AnyRuuviTagSensor {
        RuuviTagSensorStruct(
            version: 5, firmwareVersion: nil, luid: nil, macId: mac.mac,
            serviceUUID: nil, isConnectable: false, name: "Notification test sensor",
            isClaimed: false, isOwner: false, owner: nil, ownersPlan: nil,
            isCloudSensor: isCloud, canShare: false, sharedTo: [], maxHistoryDays: nil
        ).any
    }
}
