import Foundation
import Future

public extension Notification.Name {
    static let RuuviTagHeartbeatDaemonDidFail = Notification.Name("RuuviTagHeartbeatDaemonDidFail")
    static let RuuviTagHeartBeatDaemonShouldRestart = Notification.Name("RuuviTagHeartBeatDaemonShouldRestart")
}

public enum RuuviTagHeartbeatDaemonDidFailKey: String {
    case error = "RuuviDaemonError" // RuuviDaemonError
}

public protocol RuuviTagHeartbeatDaemon {
    func start()
    func stop()
    func restart()
}

public protocol RuuviTagHeartbeatDaemonTitles {
    var didConnect: String { get }
    var didDisconnect: String { get }
}
