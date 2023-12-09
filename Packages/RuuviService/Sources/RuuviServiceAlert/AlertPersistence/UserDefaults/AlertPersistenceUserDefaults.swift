import Foundation
import RuuviOntology

// swiftlint:disable file_length type_body_length
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
    private let temperatureAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureAlertIsTriggeredUDKeyPrefix."
    private let temperatureAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureAlertTriggeredAtUDKeyPrefix."

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
    private let humidityAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.humidityAlertIsTriggeredUDKeyPrefix."
    private let humidityAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.humidityAlertTriggeredAtUDKeyPrefix."

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
    private let relativeHumidityAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertIsTriggeredUDKeyPrefix."
    private let relativeHumidityAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertTriggeredAtUDKeyPrefix."

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
    private let pressureAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertIsTriggeredUDKeyPrefix."
    private let pressureAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertTriggeredAtUDKeyPrefix."

    // signal
    private let signalLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalLowerBoundUDKeyPrefix."
    private let signalUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalUpperBoundUDKeyPrefix."
    private let signalAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalAlertIsOnUDKeyPrefix."
    private let signalAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalAlertDescriptionUDKeyPrefix."
    private let signalAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalAlertMuteTillDateUDKeyPrefix."
    private let signalAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalAlertIsTriggeredUDKeyPrefix."
    private let signalAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalAlertTriggeredAtUDKeyPrefix."

    // connection
    private let connectionAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertIsOnUDKeyPrefix."
    private let connectionAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertDescriptionUDKeyPrefix."
    private let connectionAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertMuteTillDateUDKeyPrefix."

    // cloud connection
    private let cloudConnectionAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertIsOnUDKeyPrefix."
    private let cloudConnectionAlertUnseenDurationUDPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertUnseenDurationUDPrefix."
    private let cloudConnectionAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertDescriptionUDKeyPrefix."
    private let cloudConnectionAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertMuteTillDateUDKeyPrefix."
    private let cloudConnectionAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertIsTriggeredUDKeyPrefix."
    private let cloudConnectionAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertTriggeredAtUDKeyPrefix."

    // movement
    private let movementAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertIsOnUDKeyPrefix."
    private let movementAlertCounterUDPrefix
        = "AlertPersistenceUserDefaults.movementAlertCounterUDPrefix."
    private let movementAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertDescriptionUDKeyPrefix."
    private let movementAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertMuteTillDateUDKeyPrefix."
    private let movementAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertIsTriggeredUDKeyPrefix."
    private let movementAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertTriggeredAtUDKeyPrefix."

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func alert(for uuid: String, of type: AlertType) -> AlertType? {
        switch type {
        case .temperature:
            if prefs.bool(forKey: temperatureAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: temperatureLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: temperatureUpperBoundUDKeyPrefix + uuid)
            {
                .temperature(lower: lower, upper: upper)
            } else {
                nil
            }
        case .relativeHumidity:
            if prefs.bool(forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
            {
                .relativeHumidity(lower: lower, upper: upper)
            } else {
                nil
            }
        case .humidity:
            if prefs.bool(forKey: humidityAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.data(forKey: humidityLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.data(forKey: humidityUpperBoundUDKeyPrefix + uuid),
               let lowerHumidity = KeyedArchiver.unarchive(lower, with: Humidity.self),
               let upperHumidity = KeyedArchiver.unarchive(upper, with: Humidity.self)
            {
                .humidity(lower: lowerHumidity, upper: upperHumidity)
            } else {
                nil
            }
        case .pressure:
            if prefs.bool(forKey: pressureAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: pressureLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: pressureUpperBoundUDKeyPrefix + uuid)
            {
                .pressure(lower: lower, upper: upper)
            } else {
                nil
            }
        case .signal:
            if prefs.bool(forKey: signalAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: signalLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: signalUpperBoundUDKeyPrefix + uuid)
            {
                .signal(lower: lower, upper: upper)
            } else {
                nil
            }
        case .connection:
            if prefs.bool(forKey: connectionAlertIsOnUDKeyPrefix + uuid) {
                .connection
            } else {
                nil
            }
        case .cloudConnection:
            if prefs.bool(forKey: cloudConnectionAlertIsOnUDKeyPrefix + uuid),
               let unseenDuration = prefs.optionalDouble(
                   forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid
               )
            {
                .cloudConnection(unseenDuration: unseenDuration)
            } else {
                nil
            }
        case .movement:
            if prefs.bool(forKey: movementAlertIsOnUDKeyPrefix + uuid),
               let counter = prefs.optionalInt(forKey: movementAlertCounterUDPrefix + uuid)
            {
                .movement(last: counter)
            } else {
                nil
            }
        }
    }

    func register(type: AlertType, for uuid: String) {
        switch type {
        case let .temperature(lower, upper):
            prefs.set(true, forKey: temperatureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
        case let .relativeHumidity(lower, upper):
            prefs.set(true, forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
        case let .humidity(lower, upper):
            prefs.set(true, forKey: humidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(KeyedArchiver.archive(object: lower), forKey: humidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(KeyedArchiver.archive(object: upper), forKey: humidityUpperBoundUDKeyPrefix + uuid)
        case let .pressure(lower, upper):
            prefs.set(true, forKey: pressureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pressureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pressureUpperBoundUDKeyPrefix + uuid)
        case let .signal(lower, upper):
            prefs.set(true, forKey: signalAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: signalLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: signalUpperBoundUDKeyPrefix + uuid)
        case .connection:
            prefs.set(true, forKey: connectionAlertIsOnUDKeyPrefix + uuid)
        case let .cloudConnection(unseenDuration):
            prefs.set(true, forKey: cloudConnectionAlertIsOnUDKeyPrefix + uuid)
            prefs.set(unseenDuration, forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid)
        case let .movement(last):
            prefs.set(true, forKey: movementAlertIsOnUDKeyPrefix + uuid)
            prefs.set(last, forKey: movementAlertCounterUDPrefix + uuid)
        }
    }

    func unregister(type: AlertType, for uuid: String) {
        switch type {
        case let .temperature(lower, upper):
            prefs.set(false, forKey: temperatureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: temperatureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: temperatureAlertTriggeredAtUDKeyPrefix + uuid)
        case let .relativeHumidity(lower, upper):
            prefs.set(false, forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: relativeHumidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: relativeHumidityAlertTriggeredAtUDKeyPrefix + uuid)
        case let .humidity(lower, upper):
            prefs.set(false, forKey: humidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(KeyedArchiver.archive(object: lower), forKey: humidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(KeyedArchiver.archive(object: upper), forKey: humidityUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: humidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: humidityAlertTriggeredAtUDKeyPrefix + uuid)
        case let .pressure(lower, upper):
            prefs.set(false, forKey: pressureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pressureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pressureUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: pressureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: pressureAlertTriggeredAtUDKeyPrefix + uuid)
        case let .signal(lower, upper):
            prefs.set(false, forKey: signalAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: signalLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: signalUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: signalAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: signalAlertTriggeredAtUDKeyPrefix + uuid)
        case .connection:
            prefs.set(false, forKey: connectionAlertIsOnUDKeyPrefix + uuid)
        case let .cloudConnection(unseenDuration):
            prefs.set(false, forKey: cloudConnectionAlertIsOnUDKeyPrefix + uuid)
            prefs.set(unseenDuration, forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid)
            prefs.set(false, forKey: cloudConnectionAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: cloudConnectionAlertTriggeredAtUDKeyPrefix + uuid)
        case let .movement(last):
            prefs.set(false, forKey: movementAlertIsOnUDKeyPrefix + uuid)
            prefs.set(last, forKey: movementAlertCounterUDPrefix + uuid)
            prefs.set(false, forKey: movementAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: movementAlertTriggeredAtUDKeyPrefix + uuid)
        }
    }

    func remove(type: AlertType, for uuid: String) {
        switch type {
        case let .temperature(lower, upper):
            prefs.removeObject(forKey: temperatureAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: temperatureLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: temperatureUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: temperatureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: temperatureAlertTriggeredAtUDKeyPrefix + uuid)
        case let .relativeHumidity(lower, upper):
            prefs.removeObject(forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: relativeHumidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: relativeHumidityAlertTriggeredAtUDKeyPrefix + uuid)
        case let .humidity(lower, upper):
            prefs.removeObject(forKey: humidityAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: humidityLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: humidityUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: humidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: humidityAlertTriggeredAtUDKeyPrefix + uuid)
        case let .pressure(lower, upper):
            prefs.removeObject(forKey: pressureAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pressureLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pressureUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pressureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pressureAlertTriggeredAtUDKeyPrefix + uuid)
        case let .signal(lower, upper):
            prefs.removeObject(forKey: signalAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: signalLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: signalUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: signalAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: signalAlertTriggeredAtUDKeyPrefix + uuid)
        case .connection:
            prefs.removeObject(forKey: connectionAlertIsOnUDKeyPrefix + uuid)
        case let .cloudConnection(unseenDuration):
            prefs.removeObject(forKey: cloudConnectionAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid)
            prefs.removeObject(forKey: cloudConnectionAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: cloudConnectionAlertTriggeredAtUDKeyPrefix + uuid)
        case let .movement(last):
            prefs.removeObject(forKey: movementAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: movementAlertCounterUDPrefix + uuid)
            prefs.removeObject(forKey: movementAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: movementAlertTriggeredAtUDKeyPrefix + uuid)
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
        case .pressure:
            prefs.set(date, forKey: pressureAlertMuteTillDateUDKeyPrefix + uuid)
        case .signal:
            prefs.set(date, forKey: signalAlertMuteTillDateUDKeyPrefix + uuid)
        case .connection:
            prefs.set(date, forKey: connectionAlertMuteTillDateUDKeyPrefix + uuid)
        case .cloudConnection:
            prefs.set(date, forKey: cloudConnectionAlertMuteTillDateUDKeyPrefix + uuid)
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
        case .pressure:
            prefs.set(nil, forKey: pressureAlertMuteTillDateUDKeyPrefix + uuid)
        case .signal:
            prefs.set(nil, forKey: signalAlertMuteTillDateUDKeyPrefix + uuid)
        case .connection:
            prefs.set(nil, forKey: connectionAlertMuteTillDateUDKeyPrefix + uuid)
        case .cloudConnection:
            prefs.set(nil, forKey: cloudConnectionAlertMuteTillDateUDKeyPrefix + uuid)
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
        case .pressure:
            return prefs.value(forKey: pressureAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .signal:
            return prefs.value(forKey: signalAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .connection:
            return prefs.value(forKey: connectionAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .cloudConnection:
            return prefs.value(forKey: cloudConnectionAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .movement:
            return prefs.value(forKey: movementAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        }
    }

    func trigger(type: AlertType, trigerred: Bool?, trigerredAt: String?, for uuid: String) {
        switch type {
        case .temperature:
            prefs.set(trigerred, forKey: temperatureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerred, forKey: temperatureAlertTriggeredAtUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.set(trigerred, forKey: relativeHumidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: relativeHumidityAlertTriggeredAtUDKeyPrefix + uuid)
        case .humidity:
            prefs.set(trigerred, forKey: humidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: humidityAlertTriggeredAtUDKeyPrefix + uuid)
        case .pressure:
            prefs.set(trigerred, forKey: pressureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: pressureAlertTriggeredAtUDKeyPrefix + uuid)
        case .signal:
            prefs.set(trigerred, forKey: signalAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: signalAlertTriggeredAtUDKeyPrefix + uuid)
        case .cloudConnection:
            prefs.set(trigerred, forKey: cloudConnectionAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: cloudConnectionAlertTriggeredAtUDKeyPrefix + uuid)
        case .movement:
            prefs.set(trigerred, forKey: movementAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: movementAlertTriggeredAtUDKeyPrefix + uuid)
        case .connection:
            break
        }
    }

    func triggered(for uuid: String, of type: AlertType) -> Bool? {
        switch type {
        case .temperature:
            prefs.bool(forKey: temperatureAlertIsTriggeredUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.bool(forKey: relativeHumidityAlertIsTriggeredUDKeyPrefix + uuid)
        case .humidity:
            prefs.bool(forKey: humidityAlertIsTriggeredUDKeyPrefix + uuid)
        case .pressure:
            prefs.bool(forKey: pressureAlertIsTriggeredUDKeyPrefix + uuid)
        case .signal:
            prefs.bool(forKey: signalAlertIsTriggeredUDKeyPrefix + uuid)
        case .cloudConnection:
            prefs.bool(forKey: cloudConnectionAlertIsTriggeredUDKeyPrefix + uuid)
        case .movement:
            prefs.bool(forKey: movementAlertIsTriggeredUDKeyPrefix + uuid)
        case .connection:
            nil
        }
    }

    func triggeredAt(for uuid: String, of type: AlertType) -> String? {
        switch type {
        case .temperature:
            prefs.string(forKey: temperatureAlertTriggeredAtUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.string(forKey: relativeHumidityAlertTriggeredAtUDKeyPrefix + uuid)
        case .humidity:
            prefs.string(forKey: humidityAlertTriggeredAtUDKeyPrefix + uuid)
        case .pressure:
            prefs.string(forKey: pressureAlertTriggeredAtUDKeyPrefix + uuid)
        case .signal:
            prefs.string(forKey: signalAlertTriggeredAtUDKeyPrefix + uuid)
        case .cloudConnection:
            prefs.string(forKey: cloudConnectionAlertTriggeredAtUDKeyPrefix + uuid)
        case .movement:
            prefs.string(forKey: movementAlertTriggeredAtUDKeyPrefix + uuid)
        case .connection:
            nil
        }
    }
}

// MARK: - Temperature

extension AlertPersistenceUserDefaults {
    func lowerCelsius(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: temperatureLowerBoundUDKeyPrefix + uuid)
    }

    func upperCelsius(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: temperatureUpperBoundUDKeyPrefix + uuid)
    }

    func setLower(celsius: Double?, for uuid: String) {
        prefs.set(celsius, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
    }

    func setUpper(celsius: Double?, for uuid: String) {
        prefs.set(celsius, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
    }

    func temperatureDescription(for uuid: String) -> String? {
        prefs.string(forKey: temperatureAlertDescriptionUDKeyPrefix + uuid)
    }

    func setTemperature(description: String?, for uuid: String) {
        prefs.set(description, forKey: temperatureAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Relative Humidity

extension AlertPersistenceUserDefaults {
    func lowerRelativeHumidity(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(relativeHumidity: Double?, for uuid: String) {
        prefs.set(relativeHumidity, forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
    }

    func upperRelativeHumidity(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(relativeHumidity: Double?, for uuid: String) {
        prefs.set(relativeHumidity, forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
    }

    func relativeHumidityDescription(for uuid: String) -> String? {
        prefs.string(forKey: relativeHumidityAlertDescriptionUDKeyPrefix + uuid)
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
        if let humidity {
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
        if let humidity {
            prefs.set(KeyedArchiver.archive(object: humidity), forKey: humidityUpperBoundUDKeyPrefix + uuid)
        } else {
            prefs.set(nil, forKey: humidityUpperBoundUDKeyPrefix + uuid)
        }
    }

    func humidityDescription(for uuid: String) -> String? {
        prefs.string(forKey: humidityAlertDescriptionUDKeyPrefix + uuid)
    }

    func setHumidity(description: String?, for uuid: String) {
        prefs.set(description, forKey: humidityAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Pressure

extension AlertPersistenceUserDefaults {
    func lowerPressure(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pressureLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(pressure: Double?, for uuid: String) {
        prefs.set(pressure, forKey: pressureLowerBoundUDKeyPrefix + uuid)
    }

    func upperPressure(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pressureUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(pressure: Double?, for uuid: String) {
        prefs.set(pressure, forKey: pressureUpperBoundUDKeyPrefix + uuid)
    }

    func pressureDescription(for uuid: String) -> String? {
        prefs.string(forKey: pressureAlertDescriptionUDKeyPrefix + uuid)
    }

    func setPressure(description: String?, for uuid: String) {
        prefs.set(description, forKey: pressureAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - RSSI

extension AlertPersistenceUserDefaults {
    func lowerSignal(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: signalLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(signal: Double?, for uuid: String) {
        prefs.set(signal, forKey: signalLowerBoundUDKeyPrefix + uuid)
    }

    func upperSignal(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: signalUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(signal: Double?, for uuid: String) {
        prefs.set(signal, forKey: signalUpperBoundUDKeyPrefix + uuid)
    }

    func signalDescription(for uuid: String) -> String? {
        prefs.string(forKey: signalAlertDescriptionUDKeyPrefix + uuid)
    }

    func setSignal(description: String?, for uuid: String) {
        prefs.set(description, forKey: signalAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Connection

extension AlertPersistenceUserDefaults {
    func connectionDescription(for uuid: String) -> String? {
        prefs.string(forKey: connectionAlertDescriptionUDKeyPrefix + uuid)
    }

    func setConnection(description: String?, for uuid: String) {
        prefs.set(description, forKey: connectionAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Cloud Connection

extension AlertPersistenceUserDefaults {
    func cloudConnectionUnseenDuration(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid)
    }

    func setCloudConnection(unseenDuration: Double?, for uuid: String) {
        prefs.set(unseenDuration, forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid)
    }

    func cloudConnectionDescription(for uuid: String) -> String? {
        prefs.string(forKey: cloudConnectionAlertDescriptionUDKeyPrefix + uuid)
    }

    func setCloudConnection(description: String?, for uuid: String) {
        prefs.set(description, forKey: cloudConnectionAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Movement

extension AlertPersistenceUserDefaults {
    func movementCounter(for uuid: String) -> Int? {
        prefs.optionalInt(forKey: movementAlertCounterUDPrefix + uuid)
    }

    func setMovement(counter: Int?, for uuid: String) {
        prefs.set(counter, forKey: movementAlertCounterUDPrefix + uuid)
    }

    func movementDescription(for uuid: String) -> String? {
        prefs.string(forKey: movementAlertDescriptionUDKeyPrefix + uuid)
    }

    func setMovement(description: String?, for uuid: String) {
        prefs.set(description, forKey: movementAlertDescriptionUDKeyPrefix + uuid)
    }
}

// swiftlint:enable file_length type_body_length
