import Foundation
import BTKit

protocol AlertService {
    func proccess(heartbeat ruuviTag: RuuviTag)
    func subscribe<T: AlertServiceObserver>(_ observer: T, to uuid: String)
    func hasRegistrations(for uuid: String) -> Bool

    func isOn(type: AlertType, for uuid: String) -> Bool
    func alert(for uuid: String, of type: AlertType) -> AlertType?
    func register(type: AlertType, for uuid: String)
    func unregister(type: AlertType, for uuid: String)

    // temperature
    func lowerCelsius(for uuid: String) -> Double?
    func setLower(celsius: Double?, for uuid: String)
    func upperCelsius(for uuid: String) -> Double?
    func setUpper(celsius: Double?, for uuid: String)
    func temperatureDescription(for uuid: String) -> String?
    func setTemperature(description: String?, for uuid: String)
}

protocol AlertServiceObserver: class {
    func alert(service: AlertService, didProcess alert: AlertType, isTriggered: Bool, for uuid: String)
}

extension Notification.Name {
    static let AlertServiceTemperatureAlertDidChange = Notification.Name("AlertServiceTemperatureAlertIsOnDidChange")
}

enum AlertServiceTemperatureAlertDidChangeKey: String {
    case uuid
}
