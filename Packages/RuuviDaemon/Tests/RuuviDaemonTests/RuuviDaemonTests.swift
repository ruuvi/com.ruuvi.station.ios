@testable import RuuviDaemon
import XCTest

final class RuuviDaemonTests: XCTestCase {
    func testDefaultObservationTokenInvalidationIsNoOp() {
        DaemonObservationToken().invalidate()
    }

    func testAsyncOperationStartsExecutingBeforeMainRuns() {
        let expectation = expectation(description: #function)
        let operation = InspectingAsyncOperation()

        operation.onMain = {
            XCTAssertTrue(operation.isExecuting)
            XCTAssertEqual(operation.state, .executing)
            operation.state = .finished
            expectation.fulfill()
        }

        operation.start()

        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(operation.isAsynchronous)
        XCTAssertTrue(operation.isFinished)
        XCTAssertTrue(operation.didRunMain)
    }

    func testCancelledAsyncOperationFinishesWithoutRunningMain() {
        let operation = InspectingAsyncOperation()

        operation.cancel()
        operation.start()

        XCTAssertTrue(operation.isFinished)
        XCTAssertFalse(operation.didRunMain)
    }
}

private final class InspectingAsyncOperation: AsyncOperation, @unchecked Sendable {
    var didRunMain = false
    var onMain: (() -> Void)?

    override func main() {
        didRunMain = true
        onMain?()
    }
}
