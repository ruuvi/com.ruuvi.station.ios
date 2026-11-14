#if canImport(RuuviCloudPure)
@testable import RuuviCloudApi
#endif
@testable import RuuviCloud
import XCTest

final class RuuviCloudVerifyTests: XCTestCase {
    func testOldServerEnvelopeWithoutSubCodeKeepsTheCode() throws {
        XCTAssertEqual(
            try apiError(#"{"result":"error","error":"Token expired.","code":"ER_TOKEN_EXPIRED"}"#),
            .erTokenExpired
        )
        XCTAssertEqual(
            try apiError(#"{"result":"error","error":"Too many attempts.","code":"ER_THROTTLED"}"#),
            .erThrottled
        )
    }

    func testVerifySubCodesArePreferredOverTheCode() throws {
        let expected: [(codes: String, error: RuuviCloudApiErrorCode)] = [
            (#""code":"ER_TOKEN_EXPIRED","sub_code":"ER_SUB_INVALID_CODE""#, .erSubInvalidCode),
            (#""code":"ER_TOKEN_EXPIRED","sub_code":"ER_SUB_CODE_USED""#, .erSubCodeUsed),
            (#""code":"ER_TOKEN_EXPIRED","sub_code":"ER_SUB_CODE_EXPIRED""#, .erSubCodeExpired),
            (#""code":"ER_THROTTLED","sub_code":"ER_SUB_TOO_MANY_ATTEMPTS""#, .erSubTooManyAttempts),
        ]
        for item in expected {
            XCTAssertEqual(
                try apiError(#"{"result":"error","error":"Refused.",\#(item.codes)}"#),
                item.error,
                item.codes
            )
        }
    }

    func testUnknownSubCodeFallsBackToTheCode() throws {
        XCTAssertEqual(
            try apiError(
                #"{"result":"error","error":"Refused.","code":"ER_TOKEN_EXPIRED","sub_code":"ER_SUB_FROM_THE_FUTURE"}"#
            ),
            .erTokenExpired
        )
    }

    func testOtherSubCodesDoNotReplaceTheCode() throws {
        XCTAssertEqual(
            try apiError(
                #"{"result":"error","error":"No user.","code":"ER_INTERNAL","sub_code":"ER_SUB_NO_USER"}"#
            ),
            .erInternal
        )
    }

    func testUnknownCodeDoesNotFailDecoding() throws {
        XCTAssertEqual(
            try apiError(#"{"result":"error","error":"Refused.","code":"ER_FROM_THE_FUTURE"}"#),
            .erInternal
        )
        XCTAssertEqual(
            try apiError(
                #"{"result":"error","error":"Refused.","code":"ER_FROM_THE_FUTURE","sub_code":"ER_SUB_CODE_USED"}"#
            ),
            .erSubCodeUsed
        )
        guard case .failure(.emptyResponse) = try verifyResult(#"{"result":"error","code":"ER_FROM_THE_FUTURE"}"#)
        else {
            return XCTFail("Expected an empty response error")
        }
    }

    func testSuccessEnvelopeStillDecodes() throws {
        let response = try verifyResult(
            #"{"result":"success","data":{"email":"user@example.com","accessToken":"token","newUser":false}}"#
        ).get()
        XCTAssertEqual(response.email, "user@example.com")
        XCTAssertEqual(response.accessToken, "token")
    }

    func testVerifyQueryCarriesTokenAndPlusAddressedEmail() throws {
        var baseComponents = URLComponents()
        baseComponents.scheme = "https"
        baseComponents.host = "example.com"
        baseComponents.path = "/verify"
        let baseUrl = try XCTUnwrap(baseComponents.url)
        let url = try XCTUnwrap(
            RuuviCloudApiURLSession.url(
                baseUrl,
                withQueryFrom: RuuviCloudApiVerifyRequest(token: "AB12", email: "first+tag@example.com")
            )
        )
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, baseComponents.scheme)
        XCTAssertEqual(components.host, baseComponents.host)
        XCTAssertEqual(components.path, baseComponents.path)
        XCTAssertEqual(components.percentEncodedQuery, "token=AB12&email=first%2Btag@example.com")
        XCTAssertEqual(
            components.queryItems,
            [
                URLQueryItem(name: "token", value: "AB12"),
                URLQueryItem(name: "email", value: "first+tag@example.com"),
            ]
        )
    }

    private func verifyResult(
        _ json: String
    ) throws -> Result<RuuviCloudApiVerifyResponse, RuuviCloudApiError> {
        try JSONDecoder().decode(
            RuuviCloudApiBaseResponse<RuuviCloudApiVerifyResponse>.self,
            from: Data(json.utf8)
        ).result
    }

    private func apiError(_ json: String) throws -> RuuviCloudApiErrorCode? {
        guard case let .failure(.api(code)) = try verifyResult(json)
        else {
            return nil
        }
        return code
    }
}
