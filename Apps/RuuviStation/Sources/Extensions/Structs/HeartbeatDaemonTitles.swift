import Foundation
import RuuviDaemon
import RuuviLocalization

struct HeartbeatDaemonTitles: RuuviTagHeartbeatDaemonTitles {
    var didConnect: String = RuuviLocalization.LocalNotificationsManager.DidConnect.title
    var didDisconnect: String = RuuviLocalization.LocalNotificationsManager.DidDisconnect.title
}
