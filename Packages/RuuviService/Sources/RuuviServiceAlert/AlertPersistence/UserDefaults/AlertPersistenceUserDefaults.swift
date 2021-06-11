// swiftlint:disable file_length
import Foundation
import RuuviOntology

// swiftlint:disable:next type_body_length
class AlertPersistenceUserDefaults: AlertPersistence {
    private let prefs = UserDefaults.standard

    // temperature
    private let temperatureLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureLowerBoundUDKeyPrefix."
    private let temperatureUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureUpperBoundUDKeyPrefix."
    private let temperatureAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureAlertIsOnUDKeyPrefix."
    private let temperatureAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureAlertDescriptionUDKeyPrefix."
    private let temperatureAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureAlertMuteTillDateUDKeyPrefix."

    // Humidity
    private let humidityLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.HumidityLowerBoundUDKeyPrefix."
    private let humidityUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.HumidityUpperBoundUDKeyPrefix."
    private let humidityAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.HumidityAlertIsOnUDKeyPrefix."
    private let humidityAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.HumidityAlertDescriptionUDKeyPrefix."
    private let humidityAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.humidityAlertMuteTillDateUDKeyPrefix."

    // Humidity
    private let relativeHumidityLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityLowerBoundUDKeyPrefix."
    private let relativeHumidityUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityUpperBoundUDKeyPrefix."
    private let relativeHumidityAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertIsOnUDKeyPrefix."
    private let relativeHumidityAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertDescriptionUDKeyPrefix."
    private let relativeHumidityAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertMuteTillDateUDKeyPrefix."

    // dew point
    private let dewPointCelsiusLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointCelsiusLowerBoundUDKeyPrefix."
    private let dewPointCelsiusUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointCelsiusUpperBoundUDKeyPrefix."
    private let dewPointAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointAlertIsOnUDKeyPrefix."
    private let dewPointAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointAlertDescriptionUDKeyPrefix."
    private let dewPointAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointAlertMuteTillDateUDKeyPrefix."

    // pressure
    private let pressureLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureLowerBoundUDKeyPrefix."
    private let pressureUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureUpperBoundUDKeyPrefix."
    private let pressureAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertIsOnUDKeyPrefix."
    private let pressureAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertDescriptionUDKeyPrefix."
    private let pressureAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertMuteTillDateUDKeyPrefix."

    // connection
    private let connectionAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertIsOnUDKeyPrefix."
    private let connectionAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertDescriptionUDKeyPrefix."
    private let connectionAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertMuteTillDateUDKeyPrefix."

    // movement
    private let movementAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertIsOnUDKeyPrefix."
    private let movementAlertCounterUDPrefix
        = "AlertPersistenceUserDefaults.movementAlertCounterUDPrefix."
    private let movementAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertDescriptionUDKeyPrefix."
    private let movementAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertMuteTillDateUDKeyPrefix."

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func alert(for uuid: String, of type: AlertType) -> AlertType? {
        switch type {
        case .temperature:
            if prefs.bool(forKey: temperatureAlertIsOnUDKeyPrefix + uuid),
                let lower = prefs.optionalDouble(forKey: temperatureLowerBoundUDKeyPrefix + uuid),
                let upper = prefs.optionalDouble(forKey: temperatureUpperBoundUDKeyPrefix + uuid) {
                return .temperature(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .relativeHumidity:
            if prefs.bool(forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid),
                let lower = prefs.optionalDouble(forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid),
                let upper = prefs.optionalDouble(forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid) {
                return .relativeHumidity(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .humidity:
            if prefs.bool(forKey: humidityAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.data(forKey: humidityLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.data(forKey: humidityUpperBoundUDKeyPrefix + uuid),
                let lowerHumidity = KeyedArchiver.unarchive(lower, with: Humidity.self),
                let upperHumidity = KeyedArchiver.unarchive(upper, with: Humidity.self) {
                return .humidity(lower: lowerHumidity, upper: upperHumidity)
            } else {
                return nil
            }
        case .dewPoint:
            if prefs.bool(forKey: dewPointAlertIsOnUDKeyPrefix + uuid),
                let lower = prefs.optionalDouble(forKey: dewPointCelsiusLowerBoundUDKeyPrefix + uuid),
                let upper = prefs.optionalDouble(forKey: dewPointCelsiusUpperBoundUDKeyPrefix + uuid) {
                return .dewPoint(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .pressure:
            if prefs.bool(forKey: pressureAlertIsOnUDKeyPrefix + uuid),
                let lower = prefs.optionalDouble(forKey: pressureLowerBoundUDKeyPrefix + uuid),
                let upper = prefs.optionalDouble(forKey: pressureUpperBoundUDKeyPrefix + uuid) {
                return .pressure(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .connection:
            if prefs.bool(forKey: connectionAlertIsOnUDKeyPrefix + uuid) {
                return .connection
            } else {
                 return nil
            }
        case .movement:
            if prefs.bool(forKey: movementAlertIsOnUDKeyPrefix + uuid),
                let counter = prefs.optionalInt(forKey: movementAlertCounterUDPrefix + uuid) {
                return .movement(last: counter)
            } else {
                return nil
            }
        }
    }

    func register(type: AlertType, for uuid: String) {
        switch type {
        case .temperature(let lower, let upper):
            prefs.set(true, forKey: temperatureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
        case .relativeHumidity(let lower, let upper):
            prefs.set(true, forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(false, forKey: dewPointAlertIsOnUDKeyPrefix + uuid)
            prefs.set(false, forKey: humidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
        case .humidity(let lower, let upper):
            prefs.set(true, forKey: humidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(false, forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(false, forKey: dewPointAlertIsOnUDKeyPrefix + uuid)
            prefs.set(KeyedArchiver.archive(object: lower), forKey: humidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(KeyedArchiver.archive(object: upper), forKey: humidityUpperBoundUDKeyPrefix + uuid)
        case .dewPoint(let lower, let upper):
            prefs.set(true, forKey: dewPointAlertIsOnUDKeyPrefix + uuid)
            prefs.set(false, forKey: humidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(false, forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: dewPointCelsiusLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: dewPointCelsiusUpperBoundUDKeyPrefix + uuid)
        case .pressure(let lower, let upper):
            prefs.set(true, forKey: pressureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pressureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pressureUpperBoundUDKeyPrefix + uuid)
        case .connection:
            prefs.set(true, forKey: connectionAlertIsOnUDKeyPrefix + uuid)
        case .movement(let last):
            prefs.set(true, forKey: movementAlertIsOnUDKeyPrefix + uuid)
            prefs.set(last, forKey: movementAlertCounterUDPrefix + uuid)
        }
    }

    func unregister(type: AlertType, for uuid: String) {
        switch type {
        case .temperature:
            prefs.set(false, forKey: temperatureAlertIsOnUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.set(false, forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid)
        case .humidity:
            prefs.set(false, forKey: humidityAlertIsOnUDKeyPrefix + uuid)
        case .dewPoint:
            prefs.set(false, forKey: dewPointAlertIsOnUDKeyPrefix + uuid)
        case .pressure:
            prefs.set(false, forKey: pressureAlertIsOnUDKeyPrefix + uuid)
        case .connection:
            prefs.set(false, forKey: connectionAlertIsOnUDKeyPrefix + uuid)
        case .movement:
            prefs.set(false, forKey: movementAlertIsOnUDKeyPrefix + uuid)
        }
    }

    func mute(type: AlertType, for uuid: String, till date: Date) {
        switch type {
        case .temperature:
            prefs.set(date, forKey: temperatureAlertMuteTillDateUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.set(date, forKey: relativeHumidityAlertMuteTillDateUDKeyPrefix + uuid)
        case .humidity:
            prefs.set(date, forKey: humidityAlertMuteTillDateUDKeyPrefix + uuid)
        case .dewPoint:
            prefs.set(date, forKey: dewPointAlertMuteTillDateUDKeyPrefix + uuid)
        case .pressure:
            prefs.set(date, forKey: pressureAlertMuteTillDateUDKeyPrefix + uuid)
        case .connection:
            prefs.set(date, forKey: connectionAlertMuteTillDateUDKeyPrefix + uuid)
        case .movement:
            prefs.set(date, forKey: movementAlertMuteTillDateUDKeyPrefix + uuid)
        }
    }

    func unmute(type: AlertType, for uuid: String) {
        switch type {
        case .temperature:
            prefs.set(nil, forKey: temperatureAlertMuteTillDateUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.set(nil, forKey: relativeHumidityAlertMuteTillDateUDKeyPrefix + uuid)
        case .humidity:
            prefs.set(nil, forKey: humidityAlertMuteTillDateUDKeyPrefix + uuid)
        case .dewPoint:
            prefs.set(nil, forKey: dewPointAlertMuteTillDateUDKeyPrefix + uuid)
        case .pressure:
            prefs.set(nil, forKey: pressureAlertMuteTillDateUDKeyPrefix + uuid)
        case .connection:
            prefs.set(nil, forKey: connectionAlertMuteTillDateUDKeyPrefix + uuid)
        case .movement:
            prefs.set(nil, forKey: movementAlertMuteTillDateUDKeyPrefix + uuid)
        }
    }

    func mutedTill(type: AlertType, for uuid: String) -> Date? {
        switch type {
        case .temperature:
            return prefs.value(forKey: temperatureAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .relativeHumidity:
            return prefs.value(forKey: relativeHumidityAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .humidity:
            return prefs.value(forKey: humidityAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .dewPoint:
            return prefs.value(forKey: dewPointAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .pressure:
            return prefs.value(forKey: pressureAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .connection:
            return prefs.value(forKey: connectionAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .movement:
            return prefs.value(forKey: movementAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        }
    }
}

// MARK: - Temperature
extension AlertPersistenceUserDefaults {
    func lowerCelsius(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: temperatureLowerBoundUDKeyPrefix + uuid)
    }

    func upperCelsius(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: temperatureUpperBoundUDKeyPrefix + uuid)
    }

    func setLower(celsius: Double?, for uuid: String) {
        prefs.set(celsius, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
    }

    func setUpper(celsius: Double?, for uuid: String) {
        prefs.set(celsius, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
    }

    func temperatureDescription(for uuid: String) -> String? {
        return prefs.string(forKey: temperatureAlertDescriptionUDKeyPrefix + uuid)
    }

    func setTemperature(description: String?, for uuid: String) {
        prefs.set(description, forKey: temperatureAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Relative Humidity
extension AlertPersistenceUserDefaults {
    func lowerRelativeHumidity(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(relativeHumidity: Double?, for uuid: String) {
        prefs.set(relativeHumidity, forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
    }

    func upperRelativeHumidity(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(relativeHumidity: Double?, for uuid: String) {
        prefs.set(relativeHumidity, forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
    }

    func relativeHumidityDescription(for uuid: String) -> String? {
        return prefs.string(forKey: relativeHumidityAlertDescriptionUDKeyPrefix + uuid)
    }

    func setRelativeHumidity(description: String?, for uuid: String) {
        prefs.set(description, forKey: relativeHumidityAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Humidity
extension AlertPersistenceUserDefaults {
    func lowerHumidity(for uuid: String) -> Humidity? {
        guard let data = prefs.data(forKey: humidityLowerBoundUDKeyPrefix + uuid) else {
            return nil
        }
        return KeyedArchiver.unarchive(data, with: Humidity.self)
    }

    func setLower(humidity: Humidity?, for uuid: String) {
        if let humidity = humidity {
            prefs.set(KeyedArchiver.archive(object: humidity), forKey: humidityLowerBoundUDKeyPrefix + uuid)
        } else {
            prefs.set(nil, forKey: humidityLowerBoundUDKeyPrefix + uuid)
        }
    }

    func upperHumidity(for uuid: String) -> Humidity? {
        guard let data = prefs.data(forKey: humidityUpperBoundUDKeyPrefix + uuid) else {
            return nil
        }
        return KeyedArchiver.unarchive(data, with: Humidity.self)
    }

    func setUpper(humidity: Humidity?, for uuid: String) {
        if let humidity = humidity {
            prefs.set(KeyedArchiver.archive(object: humidity), forKey: humidityUpperBoundUDKeyPrefix + uuid)
        } else {
            prefs.set(nil, forKey: humidityUpperBoundUDKeyPrefix + uuid)
        }
    }

    func humidityDescription(for uuid: String) -> String? {
        return prefs.string(forKey: humidityAlertDescriptionUDKeyPrefix + uuid)
    }

    func setHumidity(description: String?, for uuid: String) {
        prefs.set(description, forKey: humidityAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Dew Point
extension AlertPersistenceUserDefaults {
    func lowerDewPointCelsius(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: dewPointCelsiusLowerBoundUDKeyPrefix + uuid)
    }

    func setLowerDewPoint(celsius: Double?, for uuid: String) {
        prefs.set(celsius, forKey: dewPointCelsiusLowerBoundUDKeyPrefix + uuid)
    }

    func upperDewPointCelsius(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: dewPointCelsiusUpperBoundUDKeyPrefix + uuid)
    }

    func setUpperDewPoint(celsius: Double?, for uuid: String) {
        prefs.set(celsius, forKey: dewPointCelsiusUpperBoundUDKeyPrefix + uuid)
    }

    func dewPointDescription(for uuid: String) -> String? {
        return prefs.string(forKey: dewPointAlertDescriptionUDKeyPrefix + uuid)
    }

    func setDewPoint(description: String?, for uuid: String) {
        prefs.set(description, forKey: dewPointAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Pressure
extension AlertPersistenceUserDefaults {
    func lowerPressure(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: pressureLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(pressure: Double?, for uuid: String) {
        prefs.set(pressure, forKey: pressureLowerBoundUDKeyPrefix + uuid)
    }

    func upperPressure(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: pressureUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(pressure: Double?, for uuid: String) {
        prefs.set(pressure, forKey: pressureUpperBoundUDKeyPrefix + uuid)
    }

    func pressureDescription(for uuid: String) -> String? {
        return prefs.string(forKey: pressureAlertDescriptionUDKeyPrefix + uuid)
    }

    func setPressure(description: String?, for uuid: String) {
        prefs.set(description, forKey: pressureAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Connection
extension AlertPersistenceUserDefaults {
    func connectionDescription(for uuid: String) -> String? {
        return prefs.string(forKey: connectionAlertDescriptionUDKeyPrefix + uuid)
    }

    func setConnection(description: String?, for uuid: String) {
        prefs.set(description, forKey: connectionAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Movement
extension AlertPersistenceUserDefaults {
    func movementCounter(for uuid: String) -> Int? {
        return prefs.optionalInt(forKey: movementAlertCounterUDPrefix + uuid)
    }

    func setMovement(counter: Int?, for uuid: String) {
        prefs.set(counter, forKey: movementAlertCounterUDPrefix + uuid)
    }

    func movementDescription(for uuid: String) -> String? {
        return prefs.string(forKey: movementAlertDescriptionUDKeyPrefix + uuid)
    }

    func setMovement(description: String?, for uuid: String) {
        prefs.set(description, forKey: movementAlertDescriptionUDKeyPrefix + uuid)
    }
}
// swiftlint:enable file_length
