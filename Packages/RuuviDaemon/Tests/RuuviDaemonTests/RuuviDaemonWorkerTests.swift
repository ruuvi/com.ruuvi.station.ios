@testable import RuuviDaemon
import CoreFoundation
import XCTest

final class RuuviDaemonWorkerTests: XCTestCase {
    func testReleasingIdleWorkerWithoutStoppingExitsItsThread() {
        let started = expectation(description: "Worker started")
        var worker: RuuviDaemonWorker? = RuuviDaemonWorker()
        weak var releasedWorker = worker
        worker?.start { started.fulfill() }
        wait(for: [started], timeout: 1)
        let thread = worker!.thread!

        autoreleasepool { worker = nil }

        let exited = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in thread.isFinished },
            object: nil
        )
        wait(for: [exited], timeout: 3)
        XCTAssertNil(releasedWorker)
        XCTAssertTrue(thread.isCancelled)
    }

    func testStartingAgainStopsIdlePreviousRunLoop() {
        let worker = StopObservingWorker()
        let firstStarted = expectation(description: "First worker started")
        let secondStarted = expectation(description: "Second worker started")
        let firstStopped = expectation(description: "Previous idle worker stopped")
        worker.start { firstStarted.fulfill() }
        wait(for: [firstStarted], timeout: 1)
        let oldThread = worker.thread!
        worker.didStop = { firstStopped.fulfill() }

        worker.start { secondStarted.fulfill() }
        let newThread = worker.thread!
        defer {
            newThread.cancel()
            worker.perform(#selector(StopObservingWorker.wake), on: newThread, with: nil, waitUntilDone: false)
        }
        wait(for: [secondStarted, firstStopped], timeout: 1)

        XCTAssertFalse(oldThread === newThread)
        XCTAssertFalse(newThread.isCancelled)
        let exited = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in oldThread.isFinished },
            object: nil
        )
        wait(for: [exited], timeout: 3)
    }

    func testReplacingWorkerPreservesPreviouslyQueuedCleanup() {
        let worker = StopObservingWorker()
        let firstStarted = expectation(description: "First worker started")
        let secondStarted = expectation(description: "Second worker started")
        let cleanedUp = expectation(description: "Queued cleanup ran")
        let stopped = expectation(description: "Old worker stopped after cleanup")
        let releaseFirst = DispatchSemaphore(value: 0)
        var didCleanUp = false
        worker.didCleanUp = {
            didCleanUp = true
            cleanedUp.fulfill()
        }
        worker.didStop = {
            XCTAssertTrue(didCleanUp)
            stopped.fulfill()
        }
        worker.start {
            firstStarted.fulfill()
            _ = releaseFirst.wait(timeout: .now() + 2)
        }
        wait(for: [firstStarted], timeout: 1)
        worker.perform(#selector(StopObservingWorker.cleanUp), on: worker.thread, with: nil, waitUntilDone: false)
        worker.start { secondStarted.fulfill() }
        let newThread = worker.thread!
        defer {
            releaseFirst.signal()
            newThread.cancel()
            worker.perform(#selector(StopObservingWorker.wake), on: newThread, with: nil, waitUntilDone: false)
        }
        wait(for: [secondStarted], timeout: 1)
        releaseFirst.signal()

        wait(for: [cleanedUp, stopped], timeout: 1)
        XCTAssertFalse(newThread.isCancelled)
    }

    func testStoppingOneWorkerLeavesOtherWorkersTimersRunning() {
        let advertisementWorker = StopObservingWorker()
        let heartbeatWorker = StopObservingWorker()
        let advertisementStarted = expectation(description: "Advertisement worker started")
        let advertisementStopped = expectation(description: "Advertisement worker stopped")
        let timerFired = expectation(description: "Other worker's timer still fires")
        advertisementWorker.didStop = { advertisementStopped.fulfill() }
        advertisementWorker.start { advertisementStarted.fulfill() }
        wait(for: [advertisementStarted], timeout: 1)
        heartbeatWorker.start {
            Timer.scheduledTimer(withTimeInterval: 0.02, repeats: false) { _ in
                timerFired.fulfill()
            }
        }
        advertisementWorker.stopWork()
        wait(for: [advertisementStopped, timerFired], timeout: 1)

        XCTAssertFalse(heartbeatWorker.thread.isCancelled)
        heartbeatWorker.stopWork()
    }

    func testQueuedStopKeepsTargetingOldThreadAfterRestart() {
        let worker = StopObservingWorker()
        let firstStarted = expectation(description: "First worker started")
        let secondStarted = expectation(description: "Next worker started")
        let stopped = expectation(description: "Queued stop processed")
        let releaseFirst = DispatchSemaphore(value: 0)
        worker.didStop = { stopped.fulfill() }
        worker.start {
            firstStarted.fulfill()
            _ = releaseFirst.wait(timeout: .now() + 2)
        }
        wait(for: [firstStarted], timeout: 1)
        let oldThread = worker.thread!
        worker.stopWork()
        worker.start { secondStarted.fulfill() }
        wait(for: [secondStarted], timeout: 1)
        let newThread = worker.thread!
        defer {
            for thread in [oldThread, newThread] {
                thread.cancel()
                worker.perform(#selector(StopObservingWorker.wake), on: thread, with: nil, waitUntilDone: false)
            }
        }
        releaseFirst.signal()
        wait(for: [stopped], timeout: 1)
        XCTAssertTrue(oldThread.isCancelled)
        XCTAssertFalse(newThread.isCancelled)
    }

    func testStoppingBeforeFirstStartIsSafe() {
        let worker = RuuviDaemonWorker()

        worker.stopWork()

        XCTAssertNil(worker.thread)
    }

    func testDelayedStopFromPreviousSessionDoesNotCancelNewSession() {
        let worker = StopObservingWorker()
        let firstStarted = expectation(description: "First foreground started")
        let secondStarted = expectation(description: "Next foreground started")
        let stopped = expectation(description: "Delayed background stop processed")
        let releaseFirst = DispatchSemaphore(value: 0)
        worker.didStop = { stopped.fulfill() }
        worker.start {
            firstStarted.fulfill()
            guard releaseFirst.wait(timeout: .now() + 2) == .success else { return }
            worker.stopWork()
        }
        wait(for: [firstStarted], timeout: 1)
        let oldThread = worker.thread!
        worker.start { secondStarted.fulfill() }
        wait(for: [secondStarted], timeout: 1)
        let newThread = worker.thread!
        defer {
            for thread in [oldThread, newThread] {
                thread.cancel()
                worker.perform(#selector(StopObservingWorker.wake), on: thread, with: nil, waitUntilDone: false)
            }
        }
        releaseFirst.signal()
        wait(for: [stopped], timeout: 1)
        XCTAssertTrue(oldThread.isCancelled, "Background stop must stop its own worker")
        XCTAssertFalse(newThread.isCancelled, "Foreground worker must keep receiving advertisements")
    }
}

private final class StopObservingWorker: RuuviDaemonWorker {
    var didStop: (() -> Void)?
    var didCleanUp: (() -> Void)?
    override func stopThread() {
        super.stopThread()
        didStop?()
    }
    @objc func wake() {
        CFRunLoopStop(CFRunLoopGetCurrent())
    }
    @objc func cleanUp() {
        didCleanUp?()
    }
}
