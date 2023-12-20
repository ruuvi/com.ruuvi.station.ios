import Foundation

public extension Notification.Name {
    static let RuuviTagPropertiesDaemonDidFail = Notification.Name("RuuviTagPropertiesDaemonDidFail")
}

public enum RuuviTagPropertiesDaemonDidFailKey: String {
    case error = "RuuviDaemonError" // RuuviDaemonError
}

public protocol RuuviTagPropertiesDaemon {
    func start()
    func stop()
}
