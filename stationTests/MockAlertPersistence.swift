import Foundation
@testable import station
class MockAlertPersistense: AlertPersistence {
    func lowerHumidity(for uuid: String) -> Humidity? {
        return nil
    }

    func setLower(humidity: Humidity?, for uuid: String) {}

    func upperHumidity(for uuid: String) -> Humidity? {
        return nil
    }

    func setUpper(humidity: Humidity?, for uuid: String) {}

    func humidityDescription(for uuid: String) -> String? {
        return nil
    }

    func setHumidity(description: String?, for uuid: String) {}

    func alert(for uuid: String, of type: AlertType) -> AlertType? {
        return .none
    }
    func register(type: AlertType, for uuid: String) {}
    func unregister(type: AlertType, for uuid: String) {}
    func lowerCelsius(for uuid: String) -> Double? {
        return nil
    }
    func setLower(celsius: Double?, for uuid: String) {}
    func upperCelsius(for uuid: String) -> Double? {
        return nil
    }
    func setUpper(celsius: Double?, for uuid: String) {}
    func temperatureDescription(for uuid: String) -> String? {
        return nil
    }
    func setTemperature(description: String?, for uuid: String) {}
    func lowerRelativeHumidity(for uuid: String) -> Double? {
        return nil
    }
    func setLower(relativeHumidity: Double?, for uuid: String) {}
    func upperRelativeHumidity(for uuid: String) -> Double? {
        return nil
    }
    func setUpper(relativeHumidity: Double?, for uuid: String) {}
    func relativeHumidityDescription(for uuid: String) -> String? {
        return nil
    }
    func setRelativeHumidity(description: String?, for uuid: String) {}
    func lowerAbsoluteHumidity(for uuid: String) -> Double? {
        return nil
    }
    func setLower(absoluteHumidity: Double?, for uuid: String) {}
    func upperAbsoluteHumidity(for uuid: String) -> Double? {
        return nil
    }
    func setUpper(absoluteHumidity: Double?, for uuid: String) {}
    func absoluteHumidityDescription(for uuid: String) -> String? {
        return nil
    }
    func setAbsoluteHumidity(description: String?, for uuid: String) {}
    func lowerDewPointCelsius(for uuid: String) -> Double? {
        return nil
    }
    func setLowerDewPoint(celsius: Double?, for uuid: String) {}
    func upperDewPointCelsius(for uuid: String) -> Double? {
        return nil
    }
    func setUpperDewPoint(celsius: Double?, for uuid: String) {}
    func dewPointDescription(for uuid: String) -> String? {
        return nil
    }
    func setDewPoint(description: String?, for uuid: String) {}
    func lowerPressure(for uuid: String) -> Double? {
        return nil
    }
    func setLower(pressure: Double?, for uuid: String) {}
    func upperPressure(for uuid: String) -> Double? {
        return nil
    }
    func setUpper(pressure: Double?, for uuid: String) {}
    func pressureDescription(for uuid: String) -> String? {
        return nil
    }
    func setPressure(description: String?, for uuid: String) {}
    func connectionDescription(for uuid: String) -> String? {
        return nil
    }
    func setConnection(description: String?, for uuid: String) {}
    func movementCounter(for uuid: String) -> Int? {
        return nil
    }
    func setMovement(counter: Int?, for uuid: String) {}
    func movementDescription(for uuid: String) -> String? {
        return nil
    }
    func setMovement(description: String?, for uuid: String) {}
}
