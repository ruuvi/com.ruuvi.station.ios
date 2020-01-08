import Foundation
import UIKit

extension Notification.Name {
    static let LNMDidReceive = Notification.Name("LNMDidReceive")
}

enum LNMDidReceiveKey: String {
    case uuid
}

protocol LocalNotificationsManager: class {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)

    func showDidConnect(uuid: String)
    func showDidDisconnect(uuid: String)
    func notifyDidMove(for uuid: String, counter: Int)
    func notify(_ reason: LowHighNotificationReason,
                _ type: LowHighNotificationType,
                for uuid: String)
}
