@testable import RuuviReactor
import RuuviPersistence
import XCTest

final class RuuviReactorTests: XCTestCase {
    func testInvalidateExecutesCancellationClosure() {
        var invalidations = 0
        let token = RuuviReactorToken {
            invalidations += 1
        }

        token.invalidate()
        token.invalidate()

        XCTAssertEqual(invalidations, 2)
    }

    func testErrorChangeCarriesPersistenceFailure() {
        let change = RuuviReactorChange<Int>.error(.ruuviPersistence(.failedToFindRuuviTag))

        guard case let .error(error) = change else {
            return XCTFail("Expected error change")
        }
        guard case let .ruuviPersistence(persistenceError) = error else {
            return XCTFail("Expected persistence error")
        }
        guard case .failedToFindRuuviTag = persistenceError else {
            return XCTFail("Expected failedToFindRuuviTag")
        }
    }
}
