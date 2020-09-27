import Foundation
import BTKit

protocol AlertService {
    func process(heartbeat ruuviTag: RuuviTagSensorRecord)
    func process(data: WPSData, for uuid: String)

    func subscribe<T: AlertServiceObserver>(_ observer: T, to uuid: String)
    func hasRegistrations(for uuid: String) -> Bool

    func isOn(type: AlertType, for uuid: String) -> Bool
    func alert(for uuid: String, of type: AlertType) -> AlertType?
    func register(type: AlertType, for uuid: String)
    func unregister(type: AlertType, for uuid: String)

    // temperature (celsius)
    func lowerCelsius(for uuid: String) -> Double?
    func setLower(celsius: Double?, for uuid: String)
    func upperCelsius(for uuid: String) -> Double?
    func setUpper(celsius: Double?, for uuid: String)
    func temperatureDescription(for uuid: String) -> String?
    func setTemperature(description: String?, for uuid: String)

    // humidity (unitHumidity)
    func lowerHumidity(for uuid: String) -> Humidity?
    func setLower(humidity: Humidity?, for uuid: String)
    func upperHumidity(for uuid: String) -> Humidity?
    func setUpper(humidity: Humidity?, for uuid: String)
    func humidityDescription(for uuid: String) -> String?
    func setHumidity(description: String?, for uuid: String)

    // dew point (celsius)
    func lowerDewPointCelsius(for uuid: String) -> Double?
    func setLowerDewPoint(celsius: Double?, for uuid: String)
    func upperDewPointCelsius(for uuid: String) -> Double?
    func setUpperDewPoint(celsius: Double?, for uuid: String)
    func dewPointDescription(for uuid: String) -> String?
    func setDewPoint(description: String?, for uuid: String)

    // pressure (hPa)
    func lowerPressure(for uuid: String) -> Double?
    func setLower(pressure: Double?, for uuid: String)
    func upperPressure(for uuid: String) -> Double?
    func setUpper(pressure: Double?, for uuid: String)
    func pressureDescription(for uuid: String) -> String?
    func setPressure(description: String?, for uuid: String)

    // connection
    func connectionDescription(for uuid: String) -> String?
    func setConnection(description: String?, for uuid: String)

    // movement
    func movementCounter(for uuid: String) -> Int?
    func setMovement(counter: Int?, for uuid: String)
    func movementDescription(for uuid: String) -> String?
    func setMovement(description: String?, for uuid: String)
}

protocol AlertServiceObserver: class {
    func alert(service: AlertService, isTriggered: Bool, for uuid: String)
}

extension Notification.Name {
    static let AlertServiceAlertDidChange = Notification.Name("AlertServiceAlertDidChange")
}

enum AlertServiceAlertDidChangeKey: String {
    case uuid
    case type
}
