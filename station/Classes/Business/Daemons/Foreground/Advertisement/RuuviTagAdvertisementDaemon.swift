import Foundation

extension Notification.Name {
    static let RuuviTagAdvertisementDaemonDidFail = Notification.Name("RuuviTagAdvertisementDaemonDidFail")
}

enum RuuviTagAdvertisementDaemonDidFailKey: String {
    case error = "RUError" // RUError
}

protocol RuuviTagAdvertisementDaemon {
    func start()
    func stop()
}
