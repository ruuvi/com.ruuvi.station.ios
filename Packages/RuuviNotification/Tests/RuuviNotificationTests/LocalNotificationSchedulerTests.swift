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
        scheduler.add(request) { _ in }
        scheduler.cancel(identifiers: [request.identifier])
        scheduler.add(request) { error in
            XCTAssertNil(error)
            completed.fulfill()
        }
        wait(for: [completed], timeout: 2)
        XCTAssertEqual(calls, ["add sensor", "pending sensor", "delivered sensor", "add sensor"])
    }
}

private final class NotificationCenterStub: LocalNotificationCenter {
    var addRequest: (UNNotificationRequest, ((Error?) -> Void)?) -> Void = { _, completion in completion?(nil) }
    var removePending: ([String]) -> Void = { _ in }
    var removeDelivered: ([String]) -> Void = { _ in }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        addRequest(request, completionHandler)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removePending(identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removeDelivered(identifiers)
    }

    func setBadgeCount(_ newBadgeCount: Int, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        completionHandler?(nil)
    }
}
