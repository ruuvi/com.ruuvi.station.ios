import Foundation
import XCTest
@testable import RuuviCloud
#if SWIFT_PACKAGE
    @testable import RuuviCloudApi
#endif

final class CloudQueryTests: XCTestCase {
    func testHistoryQueryPreservesFractionalTimestampsBoundsAndSort() throws {
        let request = RuuviCloudApiGetSensorRequest(
            sensor: "AA:BB:CC:DD:EE:FF", until: 1700000100.75,
            since: 1700000000.25, limit: 5000, sort: .desc)
        let query = try Dictionary(
            uniqueKeysWithValues: RuuviCloudQuery.items(for: request).map { ($0.name, $0.value!) })
        XCTAssertEqual(
            query,
            [
                "sensor": "AA:BB:CC:DD:EE:FF", "since": "1700000000.25",
                "until": "1700000100.75", "limit": "5000", "sort": "desc",
            ])
    }

    func testQueryEscapesIdentityAndDistinguishesBooleanFromInteger() throws {
        struct Request: Encodable {
            let token = "a+b&=?#/% 温度"
            let count = 1
            let enabled = true
            let disabled = false
            let absent: String? = nil
        }
        var components = URLComponents(string: "https://example.invalid/verify")!
        components.queryItems = try RuuviCloudQuery.items(for: Request())
        let decoded = try XCTUnwrap(URLComponents(url: try XCTUnwrap(components.url), resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (decoded.queryItems ?? []).map { ($0.name, $0.value!) })
        XCTAssertEqual(query, ["token": Request().token, "count": "1", "enabled": "true", "disabled": "false"])
    }

    func testEmptyAndNullParametersAreOmittedAndUnsupportedShapesFail() throws {
        struct Null: Encodable {
            enum Key: String, CodingKey { case optional }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: Key.self)
                try container.encodeNil(forKey: .optional)
            }
        }
        XCTAssertTrue(try RuuviCloudQuery.items(for: RuuviCloudApiUserRequest()).isEmpty)
        XCTAssertTrue(try RuuviCloudQuery.items(for: Null()).isEmpty)
        XCTAssertThrowsError(try RuuviCloudQuery.items(for: [1, 2]))
        XCTAssertThrowsError(try RuuviCloudQuery.items(for: ["nested": [1, 2]]))
        XCTAssertThrowsError(try RuuviCloudQuery.items(for: ["invalid": Double.nan]))
    }
}
