import Foundation

extension Notification.Name {
    static let RuuviTagPropertiesDaemonDidFail = Notification.Name("RuuviTagPropertiesDaemonDidFail")
}

enum RuuviTagPropertiesDaemonDidFailKey: String {
    case error = "RUError" // RUError
}

protocol RuuviTagPropertiesDaemon {
    func start()
    func stop()
}
