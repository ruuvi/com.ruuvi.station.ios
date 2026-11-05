import Foundation
import XCTest
@testable import RuuviCloud
#if SWIFT_PACKAGE
    @testable import RuuviCloudApi
#endif

final class CloudResponseTests: XCTestCase {
    func testEmptySuccessAndIncompleteErrorsKeepTheirMeaning() throws {
        let emptySuccess = try decode(
            RuuviCloudApiBaseResponse<RuuviCloudApiPostSettingResponse>.self,
            #"{"result":"success"}"#)
        XCTAssertNoThrow(try emptySuccess.result.get())
        let requiredData = try decode(
            RuuviCloudApiBaseResponse<RuuviCloudApiUserResponse>.self,
            #"{"result":"success"}"#)
        XCTAssertThrowsError(try requiredData.result.get()) { error in
            guard case RuuviCloudApiError.emptyResponse = error else { return XCTFail("\(error)") }
        }
        for payload in [
            #"{"result":"error"}"#, #"{"result":"error","error":"Server failure"}"#,
            #"{"result":"error","code":"ER_FORBIDDEN"}"#,
        ] {
            let response = try decode(RuuviCloudApiBaseResponse<RuuviCloudApiUserResponse>.self, payload)
            XCTAssertThrowsError(try response.result.get()) { error in
                if payload.contains("ER_FORBIDDEN") {
                    guard case RuuviCloudApiError.api(.erForbidden) = error else { return XCTFail("\(error)") }
                } else if payload.contains("Server failure") {
                    guard case RuuviCloudApiError.api(.erInternal) = error else { return XCTFail("\(error)") }
                } else {
                    guard case RuuviCloudApiError.emptyResponse = error else { return XCTFail("\(error)") }
                }
            }
        }
        XCTAssertThrowsError(
            try decode(
                RuuviCloudApiBaseResponse<RuuviCloudApiUserResponse>.self,
                #"{"result":"unsupported"}"#))
    }

    func testSensorSettingsAcceptArrayAndLegacyJSONStringPreservingTimestamps() throws {
        typealias Settings = RuuviCloudApiGetSensorsDenseResponse.CloudApiSensor.CloudApiSensorSettings
        for order: Any in [["TEMPERATURE_F", "CO2_PPM"], #"["TEMPERATURE_F","CO2_PPM"]"#] {
            let data = try JSONSerialization.data(withJSONObject: [
                "displayOrder": order, "defaultDisplayOrder": " false ", "description": "Sauna",
                "displayOrder_lastUpdated": 100, "defaultDisplayOrder_lastUpdated": 200,
                "description_lastUpdated": 300, "newServerField": true,
            ])
            let settings = try JSONDecoder().decode(Settings.self, from: data)
            XCTAssertEqual(settings.displayOrderCodes, ["TEMPERATURE_F", "CO2_PPM"])
            XCTAssertEqual(settings.defaultDisplayOrder, false)
            XCTAssertEqual(settings.description, "Sauna")
            XCTAssertEqual(settings.displayOrderLastUpdatedDate, Date(timeIntervalSince1970: 100))
            XCTAssertEqual(settings.defaultDisplayOrderLastUpdatedDate, Date(timeIntervalSince1970: 200))
            XCTAssertEqual(settings.descriptionLastUpdatedDate, Date(timeIntervalSince1970: 300))
        }
        XCTAssertEqual(try decode(Settings.self, #"{"defaultDisplayOrder":" TRUE "}"#).defaultDisplayOrder, true)
        for payload in [
            "{}", #"{"displayOrder":"not JSON","defaultDisplayOrder":"unknown"}"#,
            #"{"displayOrder":42,"defaultDisplayOrder":42}"#,
        ] {
            let settings = try decode(Settings.self, payload)
            XCTAssertNil(settings.displayOrderCodes)
            XCTAssertNil(settings.defaultDisplayOrder)
            XCTAssertNil(settings.displayOrderLastUpdatedDate)
            XCTAssertNil(settings.defaultDisplayOrderLastUpdatedDate)
            XCTAssertNil(settings.descriptionLastUpdatedDate)
        }
    }

    func testMeasurementDatesNeverInventFreshnessForMissingOrNonfiniteTimestamps() throws {
        XCTAssertEqual(
            try decode(UserApiSensorRecord.self, #"{"timestamp":123.5}"#).date,
            Date(timeIntervalSince1970: 123.5))
        XCTAssertNil(try decode(UserApiSensorRecord.self, "{}").date)
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        for invalid in ["inf", "-inf", "nan"] {
            let record = try decoder.decode(UserApiSensorRecord.self, from: Data("{\"timestamp\":\"\(invalid)\"}".utf8))
            XCTAssertNil(record.date)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ text: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(text.utf8))
    }
}
