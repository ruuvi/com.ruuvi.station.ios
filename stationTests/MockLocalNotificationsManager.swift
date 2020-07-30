import UIKit
@testable import station

class MockLocalNotificationsManager: LocalNotificationsManager {
    var reason: LowHighNotificationReason?
    var type: LowHighNotificationType?
    var uuid: String?
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    }
    func showDidConnect(uuid: String) {
    }
    func showDidDisconnect(uuid: String) {
    }
    func notifyDidMove(for uuid: String, counter: Int) {
    }
    func notify(_ reason: LowHighNotificationReason, _ type: LowHighNotificationType, for uuid: String) {
        self.reason = reason
        self.type = type
        self.uuid = uuid
    }
}
