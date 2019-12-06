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

    // relative humidity
    func lowerRelativeHumidity(for uuid: String) -> Double?
    func setLower(relativeHumidity: Double?, for uuid: String)
    func upperRelativeHumidity(for uuid: String) -> Double?
    func setUpper(relativeHumidity: Double?, for uuid: String)
    func relativeHumidityDescription(for uuid: String) -> String?
    func setRelativeHumidity(description: String?, for uuid: String)
}

protocol AlertServiceObserver: class {
    func alert(service: AlertService, didProcess alert: AlertType, isTriggered: Bool, for uuid: String)
}

extension Notification.Name {
    static let AlertServiceTemperatureAlertDidChange = Notification.Name("AlertServiceTemperatureAlertIsOnDidChange")
    static let AlertServiceRelativeHumidityAlertDidChange = Notification.Name("AlertServiceRelativeHumidityAlertDidChange")
}

enum AlertServiceDidChangeKey: String {
    case uuid
}
