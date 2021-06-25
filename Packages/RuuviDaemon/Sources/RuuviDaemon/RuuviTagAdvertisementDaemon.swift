import Foundation

extension Notification.Name {
    public static let RuuviTagAdvertisementDaemonDidFail = Notification.Name("RuuviTagAdvertisementDaemonDidFail")
}

public enum RuuviTagAdvertisementDaemonDidFailKey: String {
    case error = "RuuviDaemonError" // RuuviDaemonError
}

public protocol RuuviTagAdvertisementDaemon {
    func start()
    func stop()
}
