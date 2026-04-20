@testable import RuuviContext
import XCTest

final class RuuviContextTests: XCTestCase {
    func testWorkerExecutesBlocksInSubmissionOrder() {
        let sut = Worker()
        let expectation = expectation(description: "all blocks executed")
        expectation.expectedFulfillmentCount = 3
        let lock = NSLock()
        var values: [Int] = []

        [1, 2, 3].forEach { value in
            sut.enqueue {
                lock.lock()
                values.append(value)
                lock.unlock()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(values, [1, 2, 3])
    }
}
