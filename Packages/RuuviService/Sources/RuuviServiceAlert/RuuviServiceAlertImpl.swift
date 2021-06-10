// swiftlint:disable file_length
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

    // Physical Sensor
    func hasRegistrations(for sensor: PhysicalSensor) -> Bool {
        return AlertType.allCases.contains(where: { isOn(type: $0, for: sensor) })
    }

    func isOn(type: AlertType, for sensor: PhysicalSensor) -> Bool {
        return alert(for: sensor, of: type) != nil
    }

    func alert(for sensor: PhysicalSensor, of type: AlertType) -> AlertType? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.alert(for: luid.value, of: type)
                ?? alertPersistence.alert(for: macId.value, of: type)
        } else if let luid = sensor.luid {
            return alertPersistence.alert(for: luid.value, of: type)
        } else if let macId = sensor.macId {
            return alertPersistence.alert(for: macId.value, of: type)
        } else {
            assertionFailure()
            return nil
        }
    }

    func register(type: AlertType, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.register(type: type, for: luid.value)
            alertPersistence.register(type: type, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.register(type: type, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.register(type: type, for: macId.value)
        } else {
            assertionFailure()
        }
        postAlertDidChange(with: sensor, of: type)
    }

    func unregister(type: AlertType, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.unregister(type: type, for: luid.value)
            alertPersistence.unregister(type: type, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.unregister(type: type, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.unregister(type: type, for: macId.value)
        } else {
            assertionFailure()
        }
        postAlertDidChange(with: sensor, of: type)
    }

    func mute(type: AlertType, for sensor: PhysicalSensor, till date: Date) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.mute(type: type, for: luid.value, till: date)
            alertPersistence.mute(type: type, for: macId.value, till: date)
        } else if let luid = sensor.luid {
            alertPersistence.mute(type: type, for: luid.value, till: date)
        } else if let macId = sensor.macId {
            alertPersistence.mute(type: type, for: macId.value, till: date)
        } else {
            assertionFailure()
        }
        postAlertDidChange(with: sensor, of: type)
    }

    func unmute(type: AlertType, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.unmute(type: type, for: luid.value)
            alertPersistence.unmute(type: type, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.unmute(type: type, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.unmute(type: type, for: macId.value)
        } else {
            assertionFailure()
        }
        postAlertDidChange(with: sensor, of: type)
    }

    func mutedTill(type: AlertType, for sensor: PhysicalSensor) -> Date? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.mutedTill(type: type, for: luid.value)
                ?? alertPersistence.mutedTill(type: type, for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.mutedTill(type: type, for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.mutedTill(type: type, for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    // Virtual Sensor
    func hasRegistrations(for sensor: VirtualSensor) -> Bool {
        return AlertType.allCases.contains(where: { isOn(type: $0, for: sensor) })
    }

    func isOn(type: AlertType, for sensor: VirtualSensor) -> Bool {
        return alert(for: sensor, of: type) != nil
    }

    func alert(for sensor: VirtualSensor, of type: AlertType) -> AlertType? {
        return alertPersistence.alert(for: sensor.id, of: type)
    }

    func mutedTill(type: AlertType, for sensor: VirtualSensor) -> Date? {
        alertPersistence.mutedTill(type: type, for: sensor.id)
    }

    func register(type: AlertType, for sensor: VirtualSensor) {
        alertPersistence.register(type: type, for: sensor.id)
        postAlertDidChange(with: sensor, of: type)
    }

    func unregister(type: AlertType, for sensor: VirtualSensor) {
        alertPersistence.unregister(type: type, for: sensor.id)
        postAlertDidChange(with: sensor, of: type)
    }

    func mute(type: AlertType, for sensor: VirtualSensor, till date: Date) {
        alertPersistence.mute(type: type, for: sensor.id, till: date)
        postAlertDidChange(with: sensor, of: type)
    }

    func unmute(type: AlertType, for sensor: VirtualSensor) {
        alertPersistence.unmute(type: type, for: sensor.id)
        postAlertDidChange(with: sensor, of: type)
    }

    // UUID
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

    private func postAlertDidChange(with sensor: PhysicalSensor, of type: AlertType) {
        NotificationCenter
            .default
            .post(
                name: .AlertServiceAlertDidChange,
                object: nil,
                userInfo: [
                    AlertServiceAlertDidChangeKey.physicalSensor: sensor,
                    AlertServiceAlertDidChangeKey.type: type
                ]
            )
    }

    private func postAlertDidChange(with sensor: VirtualSensor, of type: AlertType) {
        NotificationCenter
            .default
            .post(
                name: .AlertServiceAlertDidChange,
                object: nil,
                userInfo: [
                    AlertServiceAlertDidChangeKey.virtualSensor: sensor,
                    AlertServiceAlertDidChangeKey.type: type
                ]
            )
    }
}

// MARK: - Temperature
extension RuuviServiceAlertImpl {
    func lowerCelsius(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerCelsius(for: luid.value)
                ?? alertPersistence.lowerCelsius(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerCelsius(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerCelsius(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setLower(celsius: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(celsius: celsius, for: luid.value)
            alertPersistence.setLower(celsius: celsius, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(celsius: celsius, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(celsius: celsius, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = celsius, let u = upperCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }

    func upperCelsius(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperCelsius(for: luid.value)
                ?? alertPersistence.upperCelsius(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperCelsius(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperCelsius(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setUpper(celsius: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(celsius: celsius, for: luid.value)
            alertPersistence.setUpper(celsius: celsius, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(celsius: celsius, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(celsius: celsius, for: macId.value)
        } else {
            assertionFailure()
        }

        if let u = celsius, let l = lowerCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }

    func temperatureDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.temperatureDescription(for: luid.value)
                ?? alertPersistence.temperatureDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.temperatureDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.temperatureDescription(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setTemperature(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setTemperature(description: description, for: luid.value)
            alertPersistence.setTemperature(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setTemperature(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setTemperature(description: description, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = lowerCelsius(for: sensor), let u = upperCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }

    func lowerCelsius(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.lowerCelsius(for: sensor.id)
    }

    func setLower(celsius: Double?, for sensor: VirtualSensor) {
        alertPersistence.setLower(celsius: celsius, for: sensor.id)
        if let l = celsius, let u = upperCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }

    func upperCelsius(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.upperCelsius(for: sensor.id)
    }

    func setUpper(celsius: Double?, for sensor: VirtualSensor) {
        alertPersistence.setUpper(celsius: celsius, for: sensor.id)
        if let u = celsius, let l = lowerCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }

    func temperatureDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.temperatureDescription(for: sensor.id)
    }

    func setTemperature(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setTemperature(description: description, for: sensor.id)
        if let l = lowerCelsius(for: sensor), let u = upperCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }

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
    func lowerHumidity(for sensor: PhysicalSensor) -> Humidity? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerHumidity(for: luid.value)
                ?? alertPersistence.lowerHumidity(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerHumidity(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerHumidity(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setLower(humidity: Humidity?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(humidity: humidity, for: luid.value)
            alertPersistence.setLower(humidity: humidity, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(humidity: humidity, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(humidity: humidity, for: macId.value)
        } else {
            assertionFailure()
        }
        if let l = humidity, let u = upperHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .humidity(lower: l, upper: u))
        }
    }

    func upperHumidity(for sensor: PhysicalSensor) -> Humidity? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperHumidity(for: luid.value)
                ?? alertPersistence.upperHumidity(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperHumidity(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperHumidity(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setUpper(humidity: Humidity?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(humidity: humidity, for: luid.value)
            alertPersistence.setUpper(humidity: humidity, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(humidity: humidity, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(humidity: humidity, for: macId.value)
        } else {
            assertionFailure()
        }
        if let u = humidity, let l = lowerHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .humidity(lower: l, upper: u))
        }
    }

    func humidityDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.humidityDescription(for: luid.value)
                ?? alertPersistence.humidityDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.humidityDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.humidityDescription(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setHumidity(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setHumidity(description: description, for: luid.value)
            alertPersistence.setHumidity(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setHumidity(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setHumidity(description: description, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = lowerHumidity(for: sensor),
           let u = upperHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .humidity(lower: l, upper: u))
        }
    }

    func lowerHumidity(for sensor: VirtualSensor) -> Humidity? {
        return alertPersistence.lowerHumidity(for: sensor.id)
    }

    func setLower(humidity: Humidity?, for sensor: VirtualSensor) {
        alertPersistence.setLower(humidity: humidity, for: sensor.id)
        if let l = humidity, let u = upperHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .humidity(lower: l, upper: u))
        }
    }

    func upperHumidity(for sensor: VirtualSensor) -> Humidity? {
        return alertPersistence.upperHumidity(for: sensor.id)
    }

    func setUpper(humidity: Humidity?, for sensor: VirtualSensor) {
        alertPersistence.setUpper(humidity: humidity, for: sensor.id)
        if let u = humidity, let l = lowerHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .humidity(lower: l, upper: u))
        }
    }

    func humidityDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.humidityDescription(for: sensor.id)
    }

    func setHumidity(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setHumidity(description: description, for: sensor.id)
        if let l = lowerHumidity(for: sensor),
           let u = upperHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .humidity(lower: l, upper: u))
        }
    }

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
    func lowerDewPointCelsius(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerDewPointCelsius(for: luid.value)
                ?? alertPersistence.lowerDewPointCelsius(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerDewPointCelsius(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerDewPointCelsius(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setLowerDewPoint(celsius: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLowerDewPoint(celsius: celsius, for: luid.value)
            alertPersistence.setLowerDewPoint(celsius: celsius, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLowerDewPoint(celsius: celsius, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLowerDewPoint(celsius: celsius, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = celsius, let u = upperDewPointCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }

    func upperDewPointCelsius(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperDewPointCelsius(for: luid.value)
                ?? alertPersistence.upperDewPointCelsius(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperDewPointCelsius(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperDewPointCelsius(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setUpperDewPoint(celsius: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpperDewPoint(celsius: celsius, for: luid.value)
            alertPersistence.setUpperDewPoint(celsius: celsius, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpperDewPoint(celsius: celsius, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpperDewPoint(celsius: celsius, for: macId.value)
        } else {
            assertionFailure()
        }
        if let u = celsius, let l = lowerDewPointCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }

    func dewPointDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.dewPointDescription(for: luid.value)
                ?? alertPersistence.dewPointDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.dewPointDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.dewPointDescription(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setDewPoint(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setDewPoint(description: description, for: luid.value)
            alertPersistence.setDewPoint(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setDewPoint(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setDewPoint(description: description, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = lowerDewPointCelsius(for: sensor), let u = upperDewPointCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }

    func lowerDewPointCelsius(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.lowerDewPointCelsius(for: sensor.id)
    }

    func setLowerDewPoint(celsius: Double?, for sensor: VirtualSensor) {
        alertPersistence.setLowerDewPoint(celsius: celsius, for: sensor.id)
        if let l = celsius, let u = upperDewPointCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }

    func upperDewPointCelsius(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.upperDewPointCelsius(for: sensor.id)
    }

    func setUpperDewPoint(celsius: Double?, for sensor: VirtualSensor) {
        alertPersistence.setUpperDewPoint(celsius: celsius, for: sensor.id)
        if let u = celsius, let l = lowerDewPointCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }

    func dewPointDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.dewPointDescription(for: sensor.id)
    }

    func setDewPoint(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setDewPoint(description: description, for: sensor.id)
        if let l = lowerDewPointCelsius(for: sensor), let u = upperDewPointCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }

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
    func lowerPressure(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerPressure(for: luid.value)
                ?? alertPersistence.lowerPressure(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerPressure(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerPressure(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setLower(pressure: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(pressure: pressure, for: luid.value)
            alertPersistence.setLower(pressure: pressure, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(pressure: pressure, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(pressure: pressure, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = pressure, let u = upperPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }

    func upperPressure(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperPressure(for: luid.value)
                ?? alertPersistence.upperPressure(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperPressure(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperPressure(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setUpper(pressure: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(pressure: pressure, for: luid.value)
            alertPersistence.setUpper(pressure: pressure, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(pressure: pressure, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(pressure: pressure, for: macId.value)
        } else {
            assertionFailure()
        }

        if let u = pressure, let l = lowerPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }

    func pressureDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.pressureDescription(for: luid.value)
                ?? alertPersistence.pressureDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.pressureDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.pressureDescription(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setPressure(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setPressure(description: description, for: luid.value)
            alertPersistence.setPressure(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setPressure(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setPressure(description: description, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = lowerPressure(for: sensor), let u = upperPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }

    func lowerPressure(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.lowerPressure(for: sensor.id)
    }

    func setLower(pressure: Double?, for sensor: VirtualSensor) {
        alertPersistence.setLower(pressure: pressure, for: sensor.id)
        if let l = pressure, let u = upperPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }

    func upperPressure(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.upperPressure(for: sensor.id)
    }

    func setUpper(pressure: Double?, for sensor: VirtualSensor) {
        alertPersistence.setUpper(pressure: pressure, for: sensor.id)
        if let u = pressure, let l = lowerPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }

    func pressureDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.pressureDescription(for: sensor.id)
    }

    func setPressure(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setPressure(description: description, for: sensor.id)
        if let l = lowerPressure(for: sensor), let u = upperPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }

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
    func connectionDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.connectionDescription(for: luid.value)
                ?? alertPersistence.connectionDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.connectionDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.connectionDescription(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setConnection(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setConnection(description: description, for: luid.value)
            alertPersistence.setConnection(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setConnection(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setConnection(description: description, for: macId.value)
        } else {
            assertionFailure()
        }
        postAlertDidChange(with: sensor, of: .connection)
    }

    func connectionDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.connectionDescription(for: sensor.id)
    }

    func setConnection(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setConnection(description: description, for: sensor.id)
        postAlertDidChange(with: sensor, of: .connection)
    }

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
    func movementCounter(for sensor: PhysicalSensor) -> Int? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.movementCounter(for: luid.value)
                ?? alertPersistence.movementCounter(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.movementCounter(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.movementCounter(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setMovement(counter: Int?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setMovement(counter: counter, for: luid.value)
            alertPersistence.setMovement(counter: counter, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setMovement(counter: counter, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setMovement(counter: counter, for: macId.value)
        } else {
            assertionFailure()
        }
        // no need to post an update, this is not user initiated action
    }

    func movementDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.movementDescription(for: luid.value)
                ?? alertPersistence.movementDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.movementDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.movementDescription(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setMovement(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setMovement(description: description, for: luid.value)
            alertPersistence.setMovement(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setMovement(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setMovement(description: description, for: macId.value)
        } else {
            assertionFailure()
        }

        if let c = movementCounter(for: sensor) {
            postAlertDidChange(with: sensor, of: .movement(last: c))
        }
    }

    func movementCounter(for sensor: VirtualSensor) -> Int? {
        return alertPersistence.movementCounter(for: sensor.id)
    }

    func setMovement(counter: Int?, for sensor: VirtualSensor) {
        alertPersistence.setMovement(counter: counter, for: sensor.id)
        // no need to post an update, this is not user initiated action
    }

    func movementDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.movementDescription(for: sensor.id)
    }

    func setMovement(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setMovement(description: description, for: sensor.id)
        if let c = movementCounter(for: sensor) {
            postAlertDidChange(with: sensor, of: .movement(last: c))
        }
    }

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
// swiftlint:enable file_length
