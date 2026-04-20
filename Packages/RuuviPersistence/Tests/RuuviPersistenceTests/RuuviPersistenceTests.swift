@testable import RuuviPersistence
import XCTest

final class RuuviPersistenceTests: XCTestCase {
    func testGrdbErrorCasePreservesUnderlyingError() {
        let underlyingError = NSError(domain: "RuuviPersistenceTests", code: 7)
        let error = RuuviPersistenceError.grdb(underlyingError)

        guard case let .grdb(wrapped as NSError) = error else {
            return XCTFail("Expected wrapped GRDB error")
        }

        XCTAssertEqual(wrapped.domain, underlyingError.domain)
        XCTAssertEqual(wrapped.code, underlyingError.code)
    }

    func testFailedToFindRuuviTagCaseIsMatchable() {
        let error = RuuviPersistenceError.failedToFindRuuviTag

        guard case .failedToFindRuuviTag = error else {
            return XCTFail("Expected failedToFindRuuviTag")
        }
    }
}
