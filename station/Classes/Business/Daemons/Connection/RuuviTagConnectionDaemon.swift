import Foundation

extension Notification.Name {
    static let RuuviTagConnectionDaemonDidFail = Notification.Name("RuuviTagConnectionDaemonDidFail")
}

enum RuuviTagConnectionDaemonDidFailKey: String {
    case error = "RUError" // RUError
}

protocol RuuviTagConnectionDaemon {
    func start()
    func stop()
}
