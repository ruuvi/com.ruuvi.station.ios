import Foundation
import Future
import RuuviOntology
import RuuviCloud

final class RuuviServiceAlertImpl: RuuviServiceAlert {
    private let cloud: RuuviCloud
    private let alertPersistence: AlertPersistence

    init(
        cloud: RuuviCloud
    ) {
        self.cloud = cloud
        self.alertPersistence = AlertPersistenceUserDefaults()
    }

    func hasRegistrations(for uuid: String) -> Bool {
        return AlertType.allCases.contains(where: { isOn(type: $0, for: uuid) })
    }

    func isOn(type: AlertType, for uuid: String) -> Bool {
        return alert(for: uuid, of: type) != nil
    }

    func alert(for uuid: String, of type: AlertType) -> AlertType? {
        return alertPersistence.alert(for: uuid, of: type)
    }

    func mutedTill(type: AlertType, for uuid: String) -> Date? {
        alertPersistence.mutedTill(type: type, for: uuid)
    }

    func register(type: AlertType, for uuid: String) {
        alertPersistence.register(type: type, for: uuid)
        postAlertDidChange(with: uuid, of: type)
    }

    func unregister(type: AlertType, for uuid: String) {
        alertPersistence.unregister(type: type, for: uuid)
        postAlertDidChange(with: uuid, of: type)
    }

    func mute(type: AlertType, for uuid: String, till date: Date) {
        alertPersistence.mute(type: type, for: uuid, till: date)
        postAlertDidChange(with: uuid, of: type)
    }

    func unmute(type: AlertType, for uuid: String) {
        alertPersistence.unmute(type: type, for: uuid)
        postAlertDidChange(with: uuid, of: type)
    }

    private func postAlertDidChange(with uuid: String, of type: AlertType) {
        NotificationCenter
            .default
            .post(
                name: .AlertServiceAlertDidChange,
                object: nil,
                userInfo: [
                    AlertServiceAlertDidChangeKey.uuid: uuid,
                    AlertServiceAlertDidChangeKey.type: type
                ]
            )
    }
}

// MARK: - Temperature
extension RuuviServiceAlertImpl {
    func lowerCelsius(for uuid: String) -> Double? {
        return alertPersistence.lowerCelsius(for: uuid)
    }

    func setLower(celsius: Double?, for uuid: String) {
        alertPersistence.setLower(celsius: celsius, for: uuid)
        if let l = celsius, let u = upperCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .temperature(lower: l, upper: u))
        }
    }

    func upperCelsius(for uuid: String) -> Double? {
        return alertPersistence.upperCelsius(for: uuid)
    }

    func setUpper(celsius: Double?, for uuid: String) {
        alertPersistence.setUpper(celsius: celsius, for: uuid)
        if let u = celsius, let l = lowerCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .temperature(lower: l, upper: u))
        }
    }

    func temperatureDescription(for uuid: String) -> String? {
        return alertPersistence.temperatureDescription(for: uuid)
    }

    func setTemperature(description: String?, for uuid: String) {
        alertPersistence.setTemperature(description: description, for: uuid)
        if let l = lowerCelsius(for: uuid), let u = upperCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .temperature(lower: l, upper: u))
        }
    }
}

// MARK: - Humidity
extension RuuviServiceAlertImpl {
    func lowerHumidity(for uuid: String) -> Humidity? {
        return alertPersistence.lowerHumidity(for: uuid)
    }

    func setLower(humidity: Humidity?, for uuid: String) {
        alertPersistence.setLower(humidity: humidity, for: uuid)
        if let l = humidity, let u = upperHumidity(for: uuid) {
            postAlertDidChange(with: uuid, of: .humidity(lower: l, upper: u))
        }
    }

    func upperHumidity(for uuid: String) -> Humidity? {
        return alertPersistence.upperHumidity(for: uuid)
    }

    func setUpper(humidity: Humidity?, for uuid: String) {
        alertPersistence.setUpper(humidity: humidity, for: uuid)
        if let u = humidity, let l = lowerHumidity(for: uuid) {
            postAlertDidChange(with: uuid, of: .humidity(lower: l, upper: u))
        }
    }

    func humidityDescription(for uuid: String) -> String? {
        return alertPersistence.humidityDescription(for: uuid)
    }

    func setHumidity(description: String?, for uuid: String) {
        alertPersistence.setHumidity(description: description, for: uuid)
        if let l = lowerHumidity(for: uuid),
           let u = upperHumidity(for: uuid) {
            postAlertDidChange(with: uuid, of: .humidity(lower: l, upper: u))
        }
    }
}

// MARK: - Dew Point
extension RuuviServiceAlertImpl {
    func lowerDewPointCelsius(for uuid: String) -> Double? {
        return alertPersistence.lowerDewPointCelsius(for: uuid)
    }

    func setLowerDewPoint(celsius: Double?, for uuid: String) {
        alertPersistence.setLowerDewPoint(celsius: celsius, for: uuid)
        if let l = celsius, let u = upperDewPointCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .dewPoint(lower: l, upper: u))
        }
    }

    func upperDewPointCelsius(for uuid: String) -> Double? {
        return alertPersistence.upperDewPointCelsius(for: uuid)
    }

    func setUpperDewPoint(celsius: Double?, for uuid: String) {
        alertPersistence.setUpperDewPoint(celsius: celsius, for: uuid)
        if let u = celsius, let l = lowerDewPointCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .dewPoint(lower: l, upper: u))
        }
    }

    func dewPointDescription(for uuid: String) -> String? {
        return alertPersistence.dewPointDescription(for: uuid)
    }

    func setDewPoint(description: String?, for uuid: String) {
        alertPersistence.setDewPoint(description: description, for: uuid)
        if let l = lowerDewPointCelsius(for: uuid), let u = upperDewPointCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .dewPoint(lower: l, upper: u))
        }
    }
}

// MARK: - Pressure
extension RuuviServiceAlertImpl {
    func lowerPressure(for uuid: String) -> Double? {
        return alertPersistence.lowerPressure(for: uuid)
    }

    func setLower(pressure: Double?, for uuid: String) {
        alertPersistence.setLower(pressure: pressure, for: uuid)
        if let l = pressure, let u = upperPressure(for: uuid) {
            postAlertDidChange(with: uuid, of: .pressure(lower: l, upper: u))
        }
    }

    func upperPressure(for uuid: String) -> Double? {
        return alertPersistence.upperPressure(for: uuid)
    }

    func setUpper(pressure: Double?, for uuid: String) {
        alertPersistence.setUpper(pressure: pressure, for: uuid)
        if let u = pressure, let l = lowerPressure(for: uuid) {
            postAlertDidChange(with: uuid, of: .pressure(lower: l, upper: u))
        }
    }

    func pressureDescription(for uuid: String) -> String? {
        return alertPersistence.pressureDescription(for: uuid)
    }

    func setPressure(description: String?, for uuid: String) {
        alertPersistence.setPressure(description: description, for: uuid)
        if let l = lowerPressure(for: uuid), let u = upperPressure(for: uuid) {
            postAlertDidChange(with: uuid, of: .pressure(lower: l, upper: u))
        }
    }
}

// MARK: - Connection
extension RuuviServiceAlertImpl {
    func connectionDescription(for uuid: String) -> String? {
        return alertPersistence.connectionDescription(for: uuid)
    }

    func setConnection(description: String?, for uuid: String) {
        alertPersistence.setConnection(description: description, for: uuid)
        postAlertDidChange(with: uuid, of: .connection)
    }
}

// MARK: - Movement
extension RuuviServiceAlertImpl {
    func movementCounter(for uuid: String) -> Int? {
        return alertPersistence.movementCounter(for: uuid)
    }

    func setMovement(counter: Int?, for uuid: String) {
        alertPersistence.setMovement(counter: counter, for: uuid)
        // no need to post an update, this is not user initiated action
    }

    func movementDescription(for uuid: String) -> String? {
        return alertPersistence.movementDescription(for: uuid)
    }

    func setMovement(description: String?, for uuid: String) {
        alertPersistence.setMovement(description: description, for: uuid)
        if let c = movementCounter(for: uuid) {
            postAlertDidChange(with: uuid, of: .movement(last: c))
        }
    }
}
