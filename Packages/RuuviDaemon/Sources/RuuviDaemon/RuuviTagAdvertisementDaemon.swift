import Foundation

extension Notification.Name {
    public static let RuuviTagAdvertisementDaemonDidFail = Notification.Name(
        "RuuviTagAdvertisementDaemonDidFail"
    )
    public static let RuuviTagAdvertisementDaemonShouldRestart = Notification.Name(
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
