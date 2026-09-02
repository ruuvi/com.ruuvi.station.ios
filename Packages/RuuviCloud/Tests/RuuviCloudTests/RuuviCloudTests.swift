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

    func testMarketingConsentRequestEncodesConsentAndSilent() throws {
        let request = RuuviCloudApiSetMarketingConsentRequest(
            consent: true,
            silent: false
        )
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Bool]

        XCTAssertEqual(object, ["consent": true, "silent": false])
    }
}
