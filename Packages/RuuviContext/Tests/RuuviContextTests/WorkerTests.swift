import Foundation
import RuuviContext
import XCTest

final class WorkerTests: XCTestCase {
    func testSubmittedWorkRunsOffTheMainThreadInFIFOOrder() async {
        let worker = Worker()
        let gate = DispatchSemaphore(value: 0)
        let completed = expectation(description: "All queued work")
        var values = [Int]()
        worker.enqueue { gate.wait() }
        for index in 0..<100 {
            worker.enqueue {
                XCTAssertFalse(Thread.isMainThread)
                values.append(index)
            }
        }
        worker.enqueue { completed.fulfill() }
        gate.signal()
        await fulfillment(of: [completed], timeout: 3)
        XCTAssertEqual(values, Array(0..<100))
    }

    func testConcurrentProducersNeverExecuteTwoJobsAtOnceOrLoseAJob() async {
        let worker = Worker()
        let completed = expectation(description: "Every job completed once")
        completed.expectedFulfillmentCount = 100
        let state = WorkerExecutionState()
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            worker.enqueue {
                state.begin(index)
                Thread.sleep(forTimeInterval: 0.001)
                state.end()
                completed.fulfill()
            }
        }
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertEqual(state.maximumConcurrent, 1)
        XCTAssertEqual(state.executed.sorted(), Array(0..<100))
    }

    func testWorkerCanBeReleasedWhilePreviouslySubmittedWorkStillCompletes() async {
        var worker: Worker? = Worker()
        weak var weakWorker = worker
        let began = expectation(description: "Work began")
        let completed = expectation(description: "Submitted work survives owner release")
        let gate = DispatchSemaphore(value: 0)
        worker?.enqueue {
            began.fulfill()
            gate.wait()
            completed.fulfill()
        }
        await fulfillment(of: [began], timeout: 3)
        worker = nil
        XCTAssertNil(weakWorker, "An idle worker must not be retained permanently by its own thread")
        gate.signal()
        await fulfillment(of: [completed], timeout: 3)
    }
}

private final class WorkerExecutionState: @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private(set) var maximumConcurrent = 0
    private(set) var executed = [Int]()
    func begin(_ index: Int) {
        lock.lock()
        active += 1
        maximumConcurrent = max(maximumConcurrent, active)
        executed.append(index)
        lock.unlock()
    }
    func end() {
        lock.lock()
        active -= 1
        lock.unlock()
    }
}
