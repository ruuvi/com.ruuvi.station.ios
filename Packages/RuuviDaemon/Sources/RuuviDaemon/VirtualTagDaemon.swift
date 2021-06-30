import Foundation

extension Notification.Name {
    public static let WebTagDaemonDidFail = Notification.Name("WebTagDaemonDidFail")
}

public enum WebTagDaemonDidFailKey: String {
    case error = "RuuviDaemonError" // RuuviDaemonError
}

public protocol VirtualTagDaemon {
    func start()
    func stop()
}
