import Foundation

public extension Notification.Name {
    static let RuuviTagPropertiesDaemonDidFail = Notification.Name("RuuviTagPropertiesDaemonDidFail")
    static let RuuviTagPropertiesExtendedLUIDChanged = Notification.Name("RuuviTagPropertiesExtendedUUIDChanged")
}

public enum RuuviTagPropertiesDaemonDidFailKey: String {
    case error = "RuuviDaemonError" // RuuviDaemonError
}

public protocol RuuviTagPropertiesDaemon {
    func start()
    func stop()
}
