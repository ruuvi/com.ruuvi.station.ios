#if SWIFT_PACKAGE
    import RuuviLocal
    import RuuviService
    import RuuviStorage
    import RuuviReactor
    import RuuviPool
    import RuuviPersistence
    import RuuviNotifier
#endif
import Foundation

public extension Notification.Name {
    static let RuuviTagHeartbeatDaemonDidFail = Notification.Name("RuuviTagHeartbeatDaemonDidFail")
    static let RuuviTagHeartBeatDaemonShouldRestart = Notification.Name("RuuviTagHeartBeatDaemonShouldRestart")
}

public enum RuuviTagHeartbeatDaemonDidFailKey: String {
    case error = "RuuviDaemonError"  // RuuviDaemonError
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
