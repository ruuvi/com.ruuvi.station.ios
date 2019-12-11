import Foundation

protocol AlertPersistence {

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

    // absolute humidity
    func lowerAbsoluteHumidity(for uuid: String) -> Double?
    func setLower(absoluteHumidity: Double?, for uuid: String)
    func upperAbsoluteHumidity(for uuid: String) -> Double?
    func setUpper(absoluteHumidity: Double?, for uuid: String)
    func absoluteHumidityDescription(for uuid: String) -> String?
    func setAbsoluteHumidity(description: String?, for uuid: String)
}
