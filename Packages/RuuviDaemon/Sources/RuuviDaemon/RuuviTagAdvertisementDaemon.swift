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
    case error = "RuuviDaemonError" // RuuviDaemonError
}

public protocol RuuviTagAdvertisementDaemon {
    func start()
    func stop()
    func restart()
}
