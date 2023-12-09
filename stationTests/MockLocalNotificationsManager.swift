@testable import station
import UIKit

class MockLocalNotificationsManager: LocalNotificationsManager {
    var reason: LowHighNotificationReason?
    var type: LowHighNotificationType?
    var uuid: String?
    func application(_: UIApplication,
                     didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) {}

    func showDidConnect(uuid _: String) {}

    func showDidDisconnect(uuid _: String) {}

    func notifyDidMove(for _: String, counter _: Int) {}

    func notify(_ reason: LowHighNotificationReason, _ type: LowHighNotificationType, for uuid: String) {
        self.reason = reason
        self.type = type
        self.uuid = uuid
    }
}
