import Foundation
import Future

extension Notification.Name {
    static let RuuviTagHeartbeatDaemonDidFail = Notification.Name("RuuviTagHeartbeatDaemonDidFail")
}

enum RuuviTagHeartbeatDaemonDidFailKey: String {
    case error = "RUError" // RUError
}

protocol RuuviTagHeartbeatDaemon {
    func start()
    func stop()
}
