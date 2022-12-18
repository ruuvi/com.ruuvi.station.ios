import Foundation
import RuuviDaemon

struct HeartbeatDaemonTitles: RuuviTagHeartbeatDaemonTitles {
    var didConnect: String = "LocalNotificationsManager.DidConnect.title".localized()
    var didDisconnect: String = "LocalNotificationsManager.DidDisconnect.title".localized()
}
