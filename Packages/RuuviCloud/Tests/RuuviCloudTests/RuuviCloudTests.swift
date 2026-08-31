@testable import RuuviCloud
@testable import RuuviCloudApi
import XCTest

final class RuuviCloudTests: XCTestCase {
    func testMarketingConsentDecodesSubscribedStatus() throws {
        let data = Data(#"{"result":"success","data":{"consent":true,"status":"subscribed"}}"#.utf8)
        let response = try JSONDecoder().decode(
            RuuviCloudApiBaseResponse<RuuviCloudMarketingConsent>.self,
            from: data
        )

        XCTAssertEqual(
            try response.result.get(),
            RuuviCloudMarketingConsent(consent: true, status: .subscribed)
        )
    }

    func testMarketingConsentDecodesUnconfirmedAsNotConsented() throws {
        let data = Data(#"{"result":"success","data":{"consent":false,"status":"unconfirmed"}}"#.utf8)
        let response = try JSONDecoder().decode(
            RuuviCloudApiBaseResponse<RuuviCloudMarketingConsent>.self,
            from: data
        )

        XCTAssertEqual(
            try response.result.get(),
            RuuviCloudMarketingConsent(consent: false, status: .unconfirmed)
        )
    }

    func testMarketingConsentRequestEncodesRequiredSubscriberFields() throws {
        let request = RuuviCloudApiSetMarketingConsentRequest(
            consent: true,
            silent: false,
            language: "DE"
        )
        let object = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(request)
        ) as? [String: Any]

        XCTAssertEqual(object?["consent"] as? Bool, true)
        XCTAssertEqual(object?["silent"] as? Bool, false)
        XCTAssertEqual(object?["joiningSource"] as? String, "ios")
        XCTAssertEqual(object?["language"] as? String, "DE")
    }

    func testMarketingConsentRequestNormalizesRegionalLanguageForSendy() throws {
        let request = RuuviCloudApiSetMarketingConsentRequest(
            consent: true,
            silent: true,
            language: "en-GB"
        )
        let object = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(request)
        ) as? [String: Any]

        XCTAssertEqual(object?["language"] as? String, "EN")
    }

    func testMarketingConsentRequestFallsBackForInvalidLanguage() throws {
        let request = RuuviCloudApiSetMarketingConsentRequest(
            consent: true,
            silent: true,
            language: "Base"
        )
        let object = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(request)
        ) as? [String: Any]

        XCTAssertEqual(object?["language"] as? String, "EN")
    }

    func testQueuedSensorSettingsKeepSeparateValuesAndOriginalTimestamp() throws {
        let request = RuuviCloudApiPostSensorSettingsRequest(
            sensor: "AA:BB:CC:DD:EE:FF",
            type: ["offsetTemperature", "offsetHumidity", "offsetPressure", "description", "displayOrder"],
            value: ["1.25", "2.5", "300", "Room", "[]"],
            timestamp: 1_700_000_001
        )
        let requests = request.individualRequests

        XCTAssertEqual(requests.count, 5)
        XCTAssertEqual(Set(requests.map(\.queueKey)).count, 5)
        for (index, setting) in requests.enumerated() {
            let restored = try JSONDecoder().decode(
                RuuviCloudApiPostSensorSettingsRequest.self,
                from: JSONEncoder().encode(setting)
            )
            XCTAssertEqual(restored.sensor, request.sensor)
            XCTAssertEqual(restored.type, [request.type[index]])
            XCTAssertEqual(restored.value, [request.value[index]])
            XCTAssertEqual(restored.timestamp, request.timestamp)
        }
    }

    func testOlderFailedEditCannotReplaceNewerQueuedEdit() {
        let older = RuuviCloudApiPostSensorSettingsRequest(
            sensor: "AA:BB:CC:DD:EE:FF",
            type: ["offsetTemperature"], value: ["1"], timestamp: 100
        )
        let newer = RuuviCloudApiPostSensorSettingsRequest(
            sensor: older.sensor, type: older.type, value: ["2"], timestamp: 101
        )

        XCTAssertNotEqual(older.queueKey, newer.queueKey)
        XCTAssertEqual(older.queueKey, older.individualRequests.first?.queueKey)
    }

    func testQueueKeysSeparateSensors() {
        let first = RuuviCloudApiPostSensorSettingsRequest(
            sensor: "AA:BB:CC:DD:EE:FF",
            type: ["offsetTemperature"], value: ["0"], timestamp: 100
        )
        let second = RuuviCloudApiPostSensorSettingsRequest(
            sensor: "AA:BB:CC:DD:EE:00", type: first.type, value: first.value, timestamp: first.timestamp
        )

        XCTAssertNotEqual(first.queueKey, second.queueKey)
    }

    func testOtherSettingsStillReplaceEarlierEditsOfTheSameField() {
        let older = RuuviCloudApiPostSensorSettingsRequest(
            sensor: "AA:BB:CC:DD:EE:FF", type: ["description"], value: ["Old"], timestamp: 100
        )
        let newer = RuuviCloudApiPostSensorSettingsRequest(
            sensor: older.sensor, type: older.type, value: ["New"], timestamp: 101
        )

        XCTAssertEqual(older.queueKey, newer.queueKey)
    }

    func testInvalidSettingArrayLengthsAreNotPartiallyQueued() {
        let request = RuuviCloudApiPostSensorSettingsRequest(
            sensor: "AA:BB:CC:DD:EE:FF",
            type: ["offsetTemperature", "offsetHumidity"], value: ["1"], timestamp: 100
        )

        XCTAssertTrue(request.individualRequests.isEmpty)
    }

    func testDenseSensorSettingsDecodeOffsetValuesAndTimestamps() throws {
        let json = Data(#"""
        {
          "offsetTemperature": "1.25",
          "offsetHumidity": "2.5",
          "offsetPressure": "300",
          "offsetTemperature_lastUpdated": 1700000001,
          "offsetHumidity_lastUpdated": 1700000002,
          "offsetPressure_lastUpdated": 1700000003
        }
        """#.utf8)

        let settings = try JSONDecoder().decode(
            RuuviCloudApiGetSensorsDenseResponse.CloudApiSensor.CloudApiSensorSettings.self,
            from: json
        )

        XCTAssertEqual(settings.offsetTemperature, 1.25)
        XCTAssertEqual(settings.offsetHumidity, 2.5)
        XCTAssertEqual(settings.offsetPressure, 300)
        XCTAssertEqual(settings.offsetTemperatureLastUpdated, 1_700_000_001)
        XCTAssertEqual(settings.offsetHumidityLastUpdated, 1_700_000_002)
        XCTAssertEqual(settings.offsetPressureLastUpdated, 1_700_000_003)
    }
}
