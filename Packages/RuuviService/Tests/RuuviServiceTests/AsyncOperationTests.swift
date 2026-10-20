@testable import RuuviService
import XCTest

final class AsyncOperationTests: XCTestCase {
    func testCancellationDuringStartupFinishesWithoutRunningMain() {
        let operation = ControlledAsyncOperation {
            XCTFail("Cancellation during startup must not submit work")
        }
        let observation = operation.observe(\.isExecuting, options: [.prior]) { operation, change in
            if change.isPrior && !operation.isCancelled {
                operation.cancel()
            }
        }
        defer { observation.invalidate() }

        operation.start()

        XCTAssertTrue(operation.isCancelled)
        XCTAssertTrue(operation.isFinished)
        XCTAssertFalse(operation.isExecuting)
    }

    func testCancellationBeforeStartDoesNotRunMain() {
        let operation = ControlledAsyncOperation {
            XCTFail("A cancelled operation must not start work")
        }

        operation.cancel()
        operation.start()

        XCTAssertTrue(operation.isCancelled)
        XCTAssertTrue(operation.isFinished)
        XCTAssertFalse(operation.isExecuting)
    }

    func testCancellationIsVisibleToCompletionBlock() {
        let started = expectation(description: "Operation started")
        let completed = expectation(description: "Operation completed")
        let operation = ControlledAsyncOperation { started.fulfill() }
        operation.completionBlock = {
            XCTAssertTrue(operation.isCancelled)
            XCTAssertTrue(operation.isFinished)
            completed.fulfill()
        }
        let queue = OperationQueue()
        queue.addOperation(operation)
        wait(for: [started], timeout: 2)

        operation.cancel()

        wait(for: [completed], timeout: 2)
        XCTAssertFalse(operation.isExecuting)
    }

    func testQueuedCancellationFinishesWithoutStartingWork() {
        let completed = expectation(description: "Cancelled queued operation completed")
        let operation = ControlledAsyncOperation {
            XCTFail("A cancelled queued operation must not start work")
        }
        operation.completionBlock = {
            XCTAssertTrue(operation.isCancelled)
            XCTAssertTrue(operation.isFinished)
            completed.fulfill()
        }
        let queue = OperationQueue()
        queue.isSuspended = true
        queue.addOperation(operation)

        operation.cancel()
        XCTAssertFalse(operation.isFinished)
        queue.isSuspended = false

        wait(for: [completed], timeout: 2)
    }

    func testSuccessfulCompletionIsNotCancelled() {
        let started = expectation(description: "Operation started")
        let completed = expectation(description: "Operation completed")
        let operation = ControlledAsyncOperation { started.fulfill() }
        operation.completionBlock = {
            XCTAssertFalse(operation.isCancelled)
            XCTAssertTrue(operation.isFinished)
            completed.fulfill()
        }
        let queue = OperationQueue()
        queue.addOperation(operation)
        wait(for: [started], timeout: 2)

        operation.state = .finished

        wait(for: [completed], timeout: 2)
    }
}

private final class ControlledAsyncOperation: AsyncOperation, @unchecked Sendable {
    private let onStart: () -> Void

    init(onStart: @escaping () -> Void) {
        self.onStart = onStart
        super.init()
    }

    override func main() {
        onStart()
    }
}
