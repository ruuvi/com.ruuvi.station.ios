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
    static let RuuviTagAdvertisementDaemonDidFail = Notification.Name(
        "RuuviTagAdvertisementDaemonDidFail"
    )
    static let RuuviTagAdvertisementDaemonShouldRestart = Notification.Name(
        "RuuviTagAdvertisementDaemonShouldRestart"
    )
}

public enum RuuviTagAdvertisementDaemonDidFailKey: String {
    case error = "RuuviDaemonError"  // RuuviDaemonError
}

public protocol RuuviTagAdvertisementDaemon {
    func start()
    func stop()
    func restart()
}
