import Foundation
import UserNotifications

protocol LocalNotificationCenter {
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    @available(iOS 16.0, *)
    func setBadgeCount(_ newBadgeCount: Int, withCompletionHandler completionHandler: ((Error?) -> Void)?)
}

extension UNUserNotificationCenter: LocalNotificationCenter {}

final class LocalNotificationScheduler {
    private let center: LocalNotificationCenter
    private let queue = DispatchQueue(label: "com.ruuvi.station.local-notifications", qos: .utility)

    init(center: LocalNotificationCenter = UNUserNotificationCenter.current()) {
        self.center = center
    }

    // Notification-center methods can wait synchronously for the system service.
    // Keep those waits off the UI thread and preserve add/cancel submission order.
    func add(_ request: UNNotificationRequest, completion: @escaping (Error?) -> Void) {
        queue.async { [center] in
            center.add(request, withCompletionHandler: completion)
        }
    }

    func cancel(identifiers: [String]) {
        queue.async { [center] in
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    @available(iOS 16.0, *)
    func setBadgeCount(_ count: Int) {
        queue.async { [center] in
            center.setBadgeCount(count, withCompletionHandler: nil)
        }
    }
}
