import Foundation
@testable import station
class MockAlertPersistense: AlertPersistence {
    func lowerHumidity(for _: String) -> Humidity? {
        nil
    }

    func setLower(humidity _: Humidity?, for _: String) {}

    func upperHumidity(for _: String) -> Humidity? {
        nil
    }

    func setUpper(humidity _: Humidity?, for _: String) {}

    func humidityDescription(for _: String) -> String? {
        nil
    }

    func setHumidity(description _: String?, for _: String) {}

    func alert(for _: String, of _: AlertType) -> AlertType? {
        .none
    }

    func register(type _: AlertType, for _: String) {}
    func unregister(type _: AlertType, for _: String) {}
    func lowerCelsius(for _: String) -> Double? {
        nil
    }

    func setLower(celsius _: Double?, for _: String) {}
    func upperCelsius(for _: String) -> Double? {
        nil
    }

    func setUpper(celsius _: Double?, for _: String) {}
    func temperatureDescription(for _: String) -> String? {
        nil
    }

    func setTemperature(description _: String?, for _: String) {}
    func lowerRelativeHumidity(for _: String) -> Double? {
        nil
    }

    func setLower(relativeHumidity _: Double?, for _: String) {}
    func upperRelativeHumidity(for _: String) -> Double? {
        nil
    }

    func setUpper(relativeHumidity _: Double?, for _: String) {}
    func relativeHumidityDescription(for _: String) -> String? {
        nil
    }

    func setRelativeHumidity(description _: String?, for _: String) {}
    func lowerAbsoluteHumidity(for _: String) -> Double? {
        nil
    }

    func setLower(absoluteHumidity _: Double?, for _: String) {}
    func upperAbsoluteHumidity(for _: String) -> Double? {
        nil
    }

    func setUpper(absoluteHumidity _: Double?, for _: String) {}
    func absoluteHumidityDescription(for _: String) -> String? {
        nil
    }

    func setAbsoluteHumidity(description _: String?, for _: String) {}
    func lowerDewPointCelsius(for _: String) -> Double? {
        nil
    }

    func setLowerDewPoint(celsius _: Double?, for _: String) {}
    func upperDewPointCelsius(for _: String) -> Double? {
        nil
    }

    func setUpperDewPoint(celsius _: Double?, for _: String) {}
    func dewPointDescription(for _: String) -> String? {
        nil
    }

    func setDewPoint(description _: String?, for _: String) {}
    func lowerPressure(for _: String) -> Double? {
        nil
    }

    func setLower(pressure _: Double?, for _: String) {}
    func upperPressure(for _: String) -> Double? {
        nil
    }

    func setUpper(pressure _: Double?, for _: String) {}
    func pressureDescription(for _: String) -> String? {
        nil
    }

    func setPressure(description _: String?, for _: String) {}
    func connectionDescription(for _: String) -> String? {
        nil
    }

    func setConnection(description _: String?, for _: String) {}
    func movementCounter(for _: String) -> Int? {
        nil
    }

    func setMovement(counter _: Int?, for _: String) {}
    func movementDescription(for _: String) -> String? {
        nil
    }

    func setMovement(description _: String?, for _: String) {}
}
