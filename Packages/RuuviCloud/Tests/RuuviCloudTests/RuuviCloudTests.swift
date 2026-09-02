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
}
