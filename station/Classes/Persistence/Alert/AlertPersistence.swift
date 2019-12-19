import Foundation

protocol AlertPersistence {

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

    // relative humidity (%)
    func lowerRelativeHumidity(for uuid: String) -> Double?
    func setLower(relativeHumidity: Double?, for uuid: String)
    func upperRelativeHumidity(for uuid: String) -> Double?
    func setUpper(relativeHumidity: Double?, for uuid: String)
    func relativeHumidityDescription(for uuid: String) -> String?
    func setRelativeHumidity(description: String?, for uuid: String)

    // absolute humidity (g/m³)
    func lowerAbsoluteHumidity(for uuid: String) -> Double?
    func setLower(absoluteHumidity: Double?, for uuid: String)
    func upperAbsoluteHumidity(for uuid: String) -> Double?
    func setUpper(absoluteHumidity: Double?, for uuid: String)
    func absoluteHumidityDescription(for uuid: String) -> String?
    func setAbsoluteHumidity(description: String?, for uuid: String)

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

    // movement counter
    func movementCounter(for uuid: String) -> Int?
    func setMovement(counter: Int?, for uuid: String)
}
