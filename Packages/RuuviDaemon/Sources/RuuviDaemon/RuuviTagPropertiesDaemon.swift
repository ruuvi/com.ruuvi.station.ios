import Foundation

extension Notification.Name {
    public static let RuuviTagPropertiesDaemonDidFail = Notification.Name("RuuviTagPropertiesDaemonDidFail")
}

public enum RuuviTagPropertiesDaemonDidFailKey: String {
    case error = "RuuviDaemonError" // RuuviDaemonError
}

public protocol RuuviTagPropertiesDaemon {
    func start()
    func stop()
}
