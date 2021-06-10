import Foundation
import Future
import RuuviOntology

extension Notification.Name {
    public static let AlertServiceAlertDidChange = Notification.Name("AlertServiceAlertDidChange")
}

public enum AlertServiceAlertDidChangeKey: String {
    case physicalSensor
    case virtualSensor
    case uuid
    case type
}

public protocol RuuviServiceAlert {
    // physical sensor
    func hasRegistrations(for sensor: PhysicalSensor) -> Bool
    func isOn(type: AlertType, for sensor: PhysicalSensor) -> Bool
    func alert(for sensor: PhysicalSensor, of type: AlertType) -> AlertType?
    func register(type: AlertType, for sensor: PhysicalSensor)
    func unregister(type: AlertType, for sensor: PhysicalSensor)
    func mute(type: AlertType, for sensor: PhysicalSensor, till date: Date)
    func unmute(type: AlertType, for sensor: PhysicalSensor)
    func mutedTill(type: AlertType, for sensor: PhysicalSensor) -> Date?

    /// temperature (celsius)
    func lowerCelsius(for sensor: PhysicalSensor) -> Double?
    func setLower(celsius: Double?, for sensor: PhysicalSensor)
    func upperCelsius(for sensor: PhysicalSensor) -> Double?
    func setUpper(celsius: Double?, for sensor: PhysicalSensor)
    func temperatureDescription(for sensor: PhysicalSensor) -> String?
    func setTemperature(description: String?, for sensor: PhysicalSensor)

    /// humidity (unitHumidity)
    func lowerHumidity(for sensor: PhysicalSensor) -> Humidity?
    func setLower(humidity: Humidity?, for sensor: PhysicalSensor)
    func upperHumidity(for sensor: PhysicalSensor) -> Humidity?
    func setUpper(humidity: Humidity?, for sensor: PhysicalSensor)
    func humidityDescription(for sensor: PhysicalSensor) -> String?
    func setHumidity(description: String?, for sensor: PhysicalSensor)

    /// dew point (celsius)
    func lowerDewPointCelsius(for sensor: PhysicalSensor) -> Double?
    func setLowerDewPoint(celsius: Double?, for sensor: PhysicalSensor)
    func upperDewPointCelsius(for sensor: PhysicalSensor) -> Double?
    func setUpperDewPoint(celsius: Double?, for sensor: PhysicalSensor)
    func dewPointDescription(for sensor: PhysicalSensor) -> String?
    func setDewPoint(description: String?, for sensor: PhysicalSensor)

    /// pressure (hPa)
    func lowerPressure(for sensor: PhysicalSensor) -> Double?
    func setLower(pressure: Double?, for sensor: PhysicalSensor)
    func upperPressure(for sensor: PhysicalSensor) -> Double?
    func setUpper(pressure: Double?, for sensor: PhysicalSensor)
    func pressureDescription(for sensor: PhysicalSensor) -> String?
    func setPressure(description: String?, for sensor: PhysicalSensor)

    /// connection
    func connectionDescription(for sensor: PhysicalSensor) -> String?
    func setConnection(description: String?, for sensor: PhysicalSensor)

    /// movement
    func movementCounter(for sensor: PhysicalSensor) -> Int?
    func setMovement(counter: Int?, for sensor: PhysicalSensor)
    func movementDescription(for sensor: PhysicalSensor) -> String?
    func setMovement(description: String?, for sensor: PhysicalSensor)

    // virtual sensor
    func hasRegistrations(for sensor: VirtualSensor) -> Bool
    func isOn(type: AlertType, for sensor: VirtualSensor) -> Bool
    func alert(for sensor: VirtualSensor, of type: AlertType) -> AlertType?
    func register(type: AlertType, for sensor: VirtualSensor)
    func unregister(type: AlertType, for sensor: VirtualSensor)
    func mute(type: AlertType, for sensor: VirtualSensor, till date: Date)
    func unmute(type: AlertType, for sensor: VirtualSensor)
    func mutedTill(type: AlertType, for sensor: VirtualSensor) -> Date?

    /// temperature (celsius)
    func lowerCelsius(for sensor: VirtualSensor) -> Double?
    func setLower(celsius: Double?, for sensor: VirtualSensor)
    func upperCelsius(for sensor: VirtualSensor) -> Double?
    func setUpper(celsius: Double?, for sensor: VirtualSensor)
    func temperatureDescription(for sensor: VirtualSensor) -> String?
    func setTemperature(description: String?, for sensor: VirtualSensor)

    /// humidity (unitHumidity)
    func lowerHumidity(for sensor: VirtualSensor) -> Humidity?
    func setLower(humidity: Humidity?, for sensor: VirtualSensor)
    func upperHumidity(for sensor: VirtualSensor) -> Humidity?
    func setUpper(humidity: Humidity?, for sensor: VirtualSensor)
    func humidityDescription(for sensor: VirtualSensor) -> String?
    func setHumidity(description: String?, for sensor: VirtualSensor)

    /// dew point (celsius)
    func lowerDewPointCelsius(for sensor: VirtualSensor) -> Double?
    func setLowerDewPoint(celsius: Double?, for sensor: VirtualSensor)
    func upperDewPointCelsius(for sensor: VirtualSensor) -> Double?
    func setUpperDewPoint(celsius: Double?, for sensor: VirtualSensor)
    func dewPointDescription(for sensor: VirtualSensor) -> String?
    func setDewPoint(description: String?, for sensor: VirtualSensor)

    /// pressure (hPa)
    func lowerPressure(for sensor: VirtualSensor) -> Double?
    func setLower(pressure: Double?, for sensor: VirtualSensor)
    func upperPressure(for sensor: VirtualSensor) -> Double?
    func setUpper(pressure: Double?, for sensor: VirtualSensor)
    func pressureDescription(for sensor: VirtualSensor) -> String?
    func setPressure(description: String?, for sensor: VirtualSensor)

    /// connection
    func connectionDescription(for sensor: VirtualSensor) -> String?
    func setConnection(description: String?, for sensor: VirtualSensor)

    /// movement
    func movementCounter(for sensor: VirtualSensor) -> Int?
    func setMovement(counter: Int?, for sensor: VirtualSensor)
    func movementDescription(for sensor: VirtualSensor) -> String?
    func setMovement(description: String?, for sensor: VirtualSensor)

    // uuid
    func hasRegistrations(for uuid: String) -> Bool
    func isOn(type: AlertType, for uuid: String) -> Bool
    func alert(for uuid: String, of type: AlertType) -> AlertType?
    func register(type: AlertType, for uuid: String)
    func unregister(type: AlertType, for uuid: String)
    func mute(type: AlertType, for uuid: String, till date: Date)
    func unmute(type: AlertType, for uuid: String)
    func mutedTill(type: AlertType, for uuid: String) -> Date?

    // temperature (celsius)
    func lowerCelsius(for uuid: String) -> Double?
    func upperCelsius(for uuid: String) -> Double?
    func temperatureDescription(for uuid: String) -> String?

    // humidity (unitHumidity)
    func lowerHumidity(for uuid: String) -> Humidity?
    func upperHumidity(for uuid: String) -> Humidity?
    func humidityDescription(for uuid: String) -> String?

    // dew point (celsius)
    func lowerDewPointCelsius(for uuid: String) -> Double?
    func upperDewPointCelsius(for uuid: String) -> Double?
    func dewPointDescription(for uuid: String) -> String?

    // pressure (hPa)
    func lowerPressure(for uuid: String) -> Double?
    func upperPressure(for uuid: String) -> Double?
    func pressureDescription(for uuid: String) -> String?

    // connection
    func connectionDescription(for uuid: String) -> String?

    // movement
    func movementCounter(for uuid: String) -> Int?
    func movementDescription(for uuid: String) -> String?
}
