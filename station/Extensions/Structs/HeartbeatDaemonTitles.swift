import Foundation
import RuuviDaemon
import Localize_Swift

struct HeartbeatDaemonTitles: RuuviTagHeartbeatDaemonTitles {
    var didConnect: String = "LocalNotificationsManager.DidConnect.title".localized()
    var didDisconnect: String = "LocalNotificationsManager.DidDisconnect.title".localized()
}
