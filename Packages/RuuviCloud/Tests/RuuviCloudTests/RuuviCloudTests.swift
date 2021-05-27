import XCTest
@testable import RuuviCloud

final class RuuviCloudTests: XCTestCase {
    func testRegister() {
        let api = apiFactory.create(baseUrl: baseUrl)
        let email = "rinat.enikeev@gmail.com"
        let request = RuuviCloudApiRegisterRequest(email: email)
        let expectation = expectation(description: "registered")
        api.register(request)
            .on(success: { response in
                XCTAssertEqual(email, response.email)
            }, failure: { error in
                XCTFail(error.localizedDescription)
            }, completion: {
                expectation.fulfill()
            })
        waitForExpectations(timeout: 3)
    }

    private let cloudFactory = RuuviCloudFactoryPure()
    private let apiFactory = RuuviCloudApiFactoryURLSession()
    private var baseUrl: URL {
        if let ruuviCloudUrl = URL(string: "https://network.ruuvi.com") {
            return ruuviCloudUrl
        } else {
            fatalError()
        }
    }
}
