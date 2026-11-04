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
    static let RuuviTagPropertiesDaemonDidFail = Notification.Name("RuuviTagPropertiesDaemonDidFail")
}

public enum RuuviTagPropertiesDaemonDidFailKey: String {
    case error = "RuuviDaemonError"  // RuuviDaemonError
}

public protocol RuuviTagPropertiesDaemon {
    func start()
    func stop()
}
