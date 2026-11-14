#if canImport(RuuviNotificationLocal)
@testable import RuuviNotificationLocal
#else
@testable import RuuviNotification
#endif
import UserNotifications
import XCTest

final class LocalNotificationSchedulerTests: XCTestCase {
    func testSlowCleanupDoesNotBlockMainThreadAndRemovesBothKindsOfNotification() {
        let center = NotificationCenterStub()
        let scheduler = LocalNotificationScheduler(center: center)
        let started = expectation(description: "System cleanup started")
        let returned = expectation(description: "Main thread returned from cleanup")
        let finished = expectation(description: "Delivered notification removed")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }

        center.removePending = { identifiers in
            XCTAssertEqual(identifiers, ["sensor-temperature"])
            XCTAssertFalse(Thread.isMainThread)
            started.fulfill()
            if !Thread.isMainThread {
                XCTAssertEqual(release.wait(timeout: .now() + 5), .success)
            }
        }
        center.removeDelivered = { identifiers in
            XCTAssertEqual(identifiers, ["sensor-temperature"])
            XCTAssertFalse(Thread.isMainThread)
            finished.fulfill()
        }

        DispatchQueue.main.async {
            scheduler.cancel(identifiers: ["sensor-temperature"])
            returned.fulfill()
        }
        wait(for: [started, returned], timeout: 2)
        release.signal()
        wait(for: [finished], timeout: 2)
    }

    func testCancellationAndReplacementAreSubmittedInOrder() {
        let center = NotificationCenterStub()
        let scheduler = LocalNotificationScheduler(center: center)
        let completed = expectation(description: "Replacement scheduled")
        var calls = [String]()
        center.addRequest = { request, completion in
            XCTAssertFalse(Thread.isMainThread)
            calls.append("add \(request.identifier)")
            completion?(nil)
        }
        center.removePending = { calls.append("pending \($0.joined())") }
        center.removeDelivered = { calls.append("delivered \($0.joined())") }

        let request = UNNotificationRequest(identifier: "sensor", content: UNMutableNotificationContent(), trigger: nil)
        scheduler.add(request) { error in
            XCTAssertNil(error)
        }
        scheduler.cancel(identifiers: [request.identifier])
        scheduler.add(request) { error in
            XCTAssertNil(error)
            completed.fulfill()
        }
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(calls, ["add sensor", "pending sensor", "delivered sensor", "add sensor"])
    }

    func testCancellationAndReplacementWaitForAsynchronousAddCompletion() {
        let center = NotificationCenterStub()
        let scheduler = LocalNotificationScheduler(center: center)
        let completed = expectation(description: "Replacement scheduled")
        let callbackQueue = DispatchQueue(label: "notification-test-callbacks")
        let lock = NSLock()
        var calls = [String]()

        func record(_ call: String) {
            lock.lock()
            defer { lock.unlock() }
            calls.append(call)
        }

        center.addRequest = { request, completion in
            XCTAssertFalse(Thread.isMainThread)
            record("add \(request.identifier)")
            callbackQueue.asyncAfter(deadline: .now() + 0.05) {
                record("added \(request.identifier)")
                completion?(nil)
            }
        }
        center.removePending = { record("pending \($0.joined())") }
        center.removeDelivered = { record("delivered \($0.joined())") }

        let request = UNNotificationRequest(identifier: "sensor", content: UNMutableNotificationContent(), trigger: nil)
        scheduler.add(request) { error in
            XCTAssertNil(error)
        }
        scheduler.cancel(identifiers: [request.identifier])
        scheduler.add(request) { error in
            XCTAssertNil(error)
            completed.fulfill()
        }
        wait(for: [completed], timeout: 2)
        lock.lock()
        defer { lock.unlock() }
        XCTAssertEqual(calls, [
            "add sensor", "added sensor", "pending sensor", "delivered sensor", "add sensor", "added sensor",
        ])
    }

    func testFailedAddDoesNotPreventCancellation() {
        let center = NotificationCenterStub()
        let scheduler = LocalNotificationScheduler(center: center)
        let failed = expectation(description: "Scheduling error delivered")
        let cancelled = expectation(description: "Cancellation completed after error")
        let error = NSError(domain: "LocalNotificationSchedulerTests", code: 1)
        center.addRequest = { _, completion in completion?(error) }
        center.removeDelivered = { _ in cancelled.fulfill() }

        let request = UNNotificationRequest(identifier: "sensor", content: UNMutableNotificationContent(), trigger: nil)
        scheduler.add(request) { receivedError in
            XCTAssertEqual(receivedError as NSError?, error)
            failed.fulfill()
        }
        scheduler.cancel(identifiers: [request.identifier])
        wait(for: [failed, cancelled], timeout: 2, enforceOrder: true)
    }
}

private final class NotificationCenterStub: LocalNotificationCenter {
    var addRequest: (UNNotificationRequest, ((Error?) -> Void)?) -> Void = { _, completion in completion?(nil) }
    var removePending: ([String]) -> Void = { _ in
        // Tests that inspect pending removals replace this default no-op.
    }
    var removeDelivered: ([String]) -> Void = { _ in
        // Tests that inspect delivered removals replace this default no-op.
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        addRequest(request, completionHandler)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removePending(identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removeDelivered(identifiers)
    }

    func setBadgeCount(_: Int, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        completionHandler?(nil)
    }
}
