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

    // temperature (humidity)
    func lowerHumidity(for uuid: String) -> Humidity?
    func setLower(humidity: Humidity, for uuid: String)
    func upperHumidity(for uuid: String) -> Humidity?
    func setUpper(humidity: Humidity, for uuid: String)
    func humidityDescription(for uuid: String) -> String?
    func setHumidity(description: String?, for uuid: String)

    // relative humidity (%)
    @available(*, deprecated, message: "Method is depricated. Use lowerRelativeHumidity(for uuid: String) -> Humidity? instead!")
    func lowerRelativeHumidity(for uuid: String) -> Double?
    @available(*, deprecated, message: "Method is depricated. Use setLower(humidity: Humidity, for uuid: String) instead!")
    func setLower(relativeHumidity: Double?, for uuid: String)
    @available(*, deprecated, message: "Method is depricated. Use upperRelativeHumidity(for uuid: String) -> Humidity? instead!")
    func upperRelativeHumidity(for uuid: String) -> Double?
    @available(*, deprecated, message: "Method is depricated. Use setUpper(humidity: Humidity, for uuid: String) instead!")
    func setUpper(relativeHumidity: Double?, for uuid: String)
    @available(*, deprecated, message: "Method is depricated. Use humidityDescription(for uuid: String) -> String? instead!")
    func relativeHumidityDescription(for uuid: String) -> String?
    @available(*, deprecated, message: "Method is depricated. Use setHumidity(description: String?, for uuid: String) instead!")
    func setRelativeHumidity(description: String?, for uuid: String)

    // absolute humidity (g/m³)
    @available(*, deprecated, message: "Method is depricated. Use lowerRelativeHumidity(for uuid: String) -> Humidity? instead!")
    func lowerAbsoluteHumidity(for uuid: String) -> Double?
    @available(*, deprecated, message: "Method is depricated. Use setLower(humidity: Humidity, for uuid: String) instead!")
    func setLower(absoluteHumidity: Double?, for uuid: String)
    @available(*, deprecated, message: "Method is depricated. Use upperRelativeHumidity(for uuid: String) -> Humidity? instead!")
    func upperAbsoluteHumidity(for uuid: String) -> Double?
    @available(*, deprecated, message: "Method is depricated. Use setUpper(humidity: Humidity, for uuid: String) instead!")
    func setUpper(absoluteHumidity: Double?, for uuid: String)
    @available(*, deprecated, message: "Method is depricated. Use humidityDescription(for uuid: String) -> String? instead!")
    func absoluteHumidityDescription(for uuid: String) -> String?
    @available(*, deprecated, message: "Method is depricated. Use setHumidity(description: String?, for uuid: String) instead!")
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

    // connection
    func connectionDescription(for uuid: String) -> String?
    func setConnection(description: String?, for uuid: String)

    // movement counter
    func movementCounter(for uuid: String) -> Int?
    func setMovement(counter: Int?, for uuid: String)
    func movementDescription(for uuid: String) -> String?
    func setMovement(description: String?, for uuid: String)
}
