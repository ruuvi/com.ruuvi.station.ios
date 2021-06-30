import Foundation
import Future

extension Notification.Name {
    public static let RuuviTagHeartbeatDaemonDidFail = Notification.Name("RuuviTagHeartbeatDaemonDidFail")
}

public enum RuuviTagHeartbeatDaemonDidFailKey: String {
    case error = "RuuviDaemonError" // RuuviDaemonError
}

public protocol RuuviTagHeartbeatDaemon {
    func start()
    func stop()
}

public protocol RuuviTagHeartbeatDaemonTitles {
    var didConnect: String { get }
    var didDisconnect: String { get }
}
