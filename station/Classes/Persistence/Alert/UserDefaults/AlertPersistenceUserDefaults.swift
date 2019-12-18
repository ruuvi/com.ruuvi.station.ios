import Foundation

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

    // relativeHumidity
    private let relativeHumidityLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityLowerBoundUDKeyPrefix."
    private let relativeHumidityUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityUpperBoundUDKeyPrefix."
    private let relativeHumidityAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertIsOnUDKeyPrefix."
    private let relativeHumidityAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertDescriptionUDKeyPrefix."

    // absoluteHumidity
    private let absoluteHumidityLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.absoluteHumidityLowerBoundUDKeyPrefix."
    private let absoluteHumidityUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.absoluteHumidityUpperBoundUDKeyPrefix."
    private let absoluteHumidityAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.absoluteHumidityAlertIsOnUDKeyPrefix."
    private let absoluteHumidityAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.absoluteHumidityAlertDescriptionUDKeyPrefix."

    // dew point
    private let dewPointCelsiusLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointCelsiusLowerBoundUDKeyPrefix."
    private let dewPointCelsiusUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointCelsiusUpperBoundUDKeyPrefix."
    private let dewPointAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointAlertIsOnUDKeyPrefix."
    private let dewPointAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointAlertDescriptionUDKeyPrefix."

    // pressure
    private let pressureLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureLowerBoundUDKeyPrefix."
    private let pressureUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureUpperBoundUDKeyPrefix."
    private let pressureAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertIsOnUDKeyPrefix."
    private let pressureAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertDescriptionUDKeyPrefix."

    // connection
    private let connectionAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertIsOnUDKeyPrefix."

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
        case .absoluteHumidity:
            if prefs.bool(forKey: absoluteHumidityAlertIsOnUDKeyPrefix + uuid),
                let lower = prefs.optionalDouble(forKey: absoluteHumidityLowerBoundUDKeyPrefix + uuid),
                let upper = prefs.optionalDouble(forKey: absoluteHumidityUpperBoundUDKeyPrefix + uuid) {
                return .absoluteHumidity(lower: lower, upper: upper)
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
            prefs.set(lower, forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
        case .absoluteHumidity(let lower, let upper):
            prefs.set(true, forKey: absoluteHumidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: absoluteHumidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: absoluteHumidityUpperBoundUDKeyPrefix + uuid)
        case .dewPoint(let lower, let upper):
            prefs.set(true, forKey: dewPointAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: dewPointCelsiusLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: dewPointCelsiusUpperBoundUDKeyPrefix + uuid)
        case .pressure(let lower, let upper):
            prefs.set(true, forKey: pressureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pressureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pressureUpperBoundUDKeyPrefix + uuid)
        case .connection:
            prefs.set(true, forKey: connectionAlertIsOnUDKeyPrefix + uuid)
        }
    }

    func unregister(type: AlertType, for uuid: String) {
        switch type {
        case .temperature:
            prefs.set(false, forKey: temperatureAlertIsOnUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.set(false, forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid)
        case .absoluteHumidity:
            prefs.set(false, forKey: absoluteHumidityAlertIsOnUDKeyPrefix + uuid)
        case .dewPoint:
            prefs.set(false, forKey: dewPointAlertIsOnUDKeyPrefix + uuid)
        case .pressure:
            prefs.set(false, forKey: pressureAlertIsOnUDKeyPrefix + uuid)
        case .connection:
            prefs.set(false, forKey: connectionAlertIsOnUDKeyPrefix + uuid)
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

// MARK: - Absolute Humidity
extension AlertPersistenceUserDefaults {
    func lowerAbsoluteHumidity(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: absoluteHumidityLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(absoluteHumidity: Double?, for uuid: String) {
        prefs.set(absoluteHumidity, forKey: absoluteHumidityLowerBoundUDKeyPrefix + uuid)
    }

    func upperAbsoluteHumidity(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: absoluteHumidityUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(absoluteHumidity: Double?, for uuid: String) {
        prefs.set(absoluteHumidity, forKey: absoluteHumidityUpperBoundUDKeyPrefix + uuid)
    }

    func absoluteHumidityDescription(for uuid: String) -> String? {
        return prefs.string(forKey: absoluteHumidityAlertDescriptionUDKeyPrefix + uuid)
    }

    func setAbsoluteHumidity(description: String?, for uuid: String) {
        prefs.set(description, forKey: absoluteHumidityAlertDescriptionUDKeyPrefix + uuid)
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
