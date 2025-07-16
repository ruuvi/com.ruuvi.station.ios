import Foundation
import UIKit
import RuuviOntology

public extension Notification.Name {
    static let LNMDidReceive = Notification.Name("LNMDidReceive")
}

public enum LNMDidReceiveKey: String {
    case uuid
}

public protocol RuuviNotificationLocalOutput: AnyObject {
    func notificationDidTap(for uuid: String)
}

public protocol RuuviNotificationLocal: AnyObject {
    func setup(
        disableTitle: String,
        muteTitle: String,
        output: RuuviNotificationLocalOutput?
    )

    func showDidConnect(uuid: String, title: String)
    func showDidDisconnect(uuid: String, title: String)
    func notifyDidMove(for uuid: String, counter: Int, title: String)
    func notify(
        _ reason: LowHighNotificationReason,
        _ type: AlertType,
        for uuid: String,
        title: String
    )
}

public enum LowHighNotificationReason {
    case high
    case low
}
