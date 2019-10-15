import Foundation

extension Notification.Name {
    static let WebTagDaemonDidFail = Notification.Name("WebTagDaemonDidFail")
}

enum WebTagDaemonDidFailKey: String {
    case error = "RUError" // RUError
}

protocol WebTagDaemon {
    func start()
    func stop()
}
