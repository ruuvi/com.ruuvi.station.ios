// swiftlint:disable file_length
import Foundation
import Future
import RuuviOntology
import RuuviCloud
import RuuviLocal
import RuuviService

// MARK: - RuuviTag
extension RuuviServiceAlertImpl {
    // swiftlint:disable:next function_body_length
    public func register(type: AlertType, ruuviTag: RuuviTagSensor) {
        register(type: type, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            switch type {
            case .temperature(let lower, let upper):
                cloud.setAlert(
                    type: .temperature,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    description: temperatureDescription(for: ruuviTag),
                    for: macId
                )
            case .relativeHumidity(let lower, let upper):
                cloud.setAlert(
                    type: .humidity,
                    isEnabled: true,
                    min: lower * 100.0, // in percent on cloud, fraction locally
                    max: upper * 100.0, // in percent on cloud, fraction locally
                    counter: nil,
                    description: relativeHumidityDescription(for: ruuviTag),
                    for: macId
                )
            case .humidity:
                break // absolute is not on cloud yet (11.06.2021)
            case .dewPoint:
                break // dew point is not on cloud yet (11.06.2021)
            case .pressure(let lower, let upper):
                cloud.setAlert(
                    type: .pressure,
                    isEnabled: true,
                    min: lower * 100, // in Pa on cloud, in hPa locally
                    max: upper * 100, // in Pa on cloud, in hPa locally
                    counter: nil,
                    description: pressureDescription(for: ruuviTag),
                    for: macId
                )
            case .connection:
                break
            case .movement(let last):
                cloud.setAlert(
                    type: .movement,
                    isEnabled: true,
                    min: nil,
                    max: nil,
                    counter: last,
                    description: movementDescription(for: ruuviTag),
                    for: macId
                )
            }
        }
    }

    // swiftlint:disable:next function_body_length
    public func unregister(type: AlertType, ruuviTag: RuuviTagSensor) {
        unregister(type: type, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            switch type {
            case .temperature(let lower, let upper):
                cloud.setAlert(
                    type: .temperature,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    description: temperatureDescription(for: ruuviTag),
                    for: macId
                )
            case .relativeHumidity(let lower, let upper):
                cloud.setAlert(
                    type: .humidity,
                    isEnabled: false,
                    min: lower * 100, // in percent on cloud, fraction locally
                    max: upper * 100, // in percent on cloud, fraction locally
                    counter: nil,
                    description: relativeHumidityDescription(for: ruuviTag),
                    for: macId
                )
            case .humidity:
                break // absolute is not on cloud yet (11.06.2021)
            case .dewPoint:
                break // dew point is not on cloud yet (11.06.2021)
            case .pressure(let lower, let upper):
                cloud.setAlert(
                    type: .pressure,
                    isEnabled: false,
                    min: lower * 100, // in Pa on cloud, in hPa locally
                    max: upper * 100, // in Pa on cloud, in hPa locally
                    counter: nil,
                    description: pressureDescription(for: ruuviTag),
                    for: macId
                )
            case .connection:
                break
            case .movement(let last):
                cloud.setAlert(
                    type: .movement,
                    isEnabled: false,
                    min: nil,
                    max: nil,
                    counter: last,
                    description: movementDescription(for: ruuviTag),
                    for: macId
                )
            }
        }
    }

    public func setLower(celsius: Double?, ruuviTag: RuuviTagSensor) {
        setLower(celsius: celsius, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .temperature,
                isEnabled: isOn(type: .temperature(lower: 0, upper: 0), for: ruuviTag),
                min: celsius,
                max: upperCelsius(for: ruuviTag),
                counter: nil,
                description: temperatureDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    public func setUpper(celsius: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(celsius: celsius, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .temperature,
                isEnabled: isOn(type: .temperature(lower: 0, upper: 0), for: ruuviTag),
                min: lowerCelsius(for: ruuviTag),
                max: celsius,
                counter: nil,
                description: temperatureDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    public func setTemperature(description: String?, ruuviTag: RuuviTagSensor) {
        setTemperature(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .temperature,
                isEnabled: isOn(type: .temperature(lower: 0, upper: 0), for: ruuviTag),
                min: lowerCelsius(for: ruuviTag),
                max: upperCelsius(for: ruuviTag),
                counter: nil,
                description: description,
                for: macId
            )
        }
    }

    public func setLower(relativeHumidity: Double?, ruuviTag: RuuviTagSensor) {
        setLower(relativeHumidity: relativeHumidity, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .humidity,
                isEnabled: isOn(type: .relativeHumidity(lower: 0, upper: 0), for: ruuviTag),
                min: (relativeHumidity ?? 0) * 100.0,
                max: (upperRelativeHumidity(for: ruuviTag) ?? 0) * 100.0,
                counter: nil,
                description: relativeHumidityDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    public func setUpper(relativeHumidity: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(relativeHumidity: relativeHumidity, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .humidity,
                isEnabled: isOn(type: .relativeHumidity(lower: 0, upper: 0), for: ruuviTag),
                min: (lowerRelativeHumidity(for: ruuviTag) ?? 0) * 100.0,
                max: (relativeHumidity ?? 0) * 100.0,
                counter: nil,
                description: relativeHumidityDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    public func setRelativeHumidity(description: String?, ruuviTag: RuuviTagSensor) {
        setRelativeHumidity(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .humidity,
                isEnabled: isOn(type: .relativeHumidity(lower: 0, upper: 0), for: ruuviTag),
                min: (lowerRelativeHumidity(for: ruuviTag) ?? 0) * 100.0,
                max: (upperRelativeHumidity(for: ruuviTag) ?? 0) * 100.0,
                counter: nil,
                description: description,
                for: macId
            )
        }
    }

    public func setLower(pressure: Double?, ruuviTag: RuuviTagSensor) {
        setLower(pressure: pressure, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pressure,
                isEnabled: isOn(type: .pressure(lower: 0, upper: 0), for: ruuviTag),
                min: (pressure ?? 0) * 100.0,
                max: (upperPressure(for: ruuviTag) ?? 0) * 100.0,
                counter: nil,
                description: pressureDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    public func setUpper(pressure: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(pressure: pressure, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pressure,
                isEnabled: isOn(type: .pressure(lower: 0, upper: 0), for: ruuviTag),
                min: (lowerPressure(for: ruuviTag) ?? 0) * 100.0,
                max: (pressure ?? 0) * 100.0,
                counter: nil,
                description: pressureDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    public func setPressure(description: String?, ruuviTag: RuuviTagSensor) {
        setPressure(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pressure,
                isEnabled: isOn(type: .pressure(lower: 0, upper: 0), for: ruuviTag),
                min: (lowerPressure(for: ruuviTag) ?? 0) * 100.0,
                max: (upperPressure(for: ruuviTag) ?? 0) * 100.0,
                counter: nil,
                description: description,
                for: macId
            )
        }
    }

    public func setMovement(description: String?, ruuviTag: RuuviTagSensor) {
        setMovement(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .movement,
                isEnabled: isOn(type: .movement(last: 0), for: ruuviTag),
                min: nil,
                max: nil,
                counter: nil,
                description: description,
                for: macId
            )
        }
    }
}

public final class RuuviServiceAlertImpl: RuuviServiceAlert {
    private let cloud: RuuviCloud
    private let alertPersistence: AlertPersistence
    private let localIDs: RuuviLocalIDs

    public init(
        cloud: RuuviCloud,
        localIDs: RuuviLocalIDs
    ) {
        self.cloud = cloud
        self.localIDs = localIDs
        self.alertPersistence = AlertPersistenceUserDefaults()
    }

    // RuuviCloudAlert
    public func sync(cloudAlerts: [RuuviCloudSensorAlerts]) {
        cloudAlerts.forEach { cloudSensorAlert in
            let macId = cloudSensorAlert.sensor.mac
            let luid = localIDs.luid(for: macId)
            let physicalSensor = PhysicalSensorStruct(luid: luid, macId: macId)
            cloudSensorAlert.alerts.forEach { cloudAlert in
                var type: AlertType?
                switch cloudAlert.type {
                case .temperature:
                    type = .temperature(lower: cloudAlert.min, upper: cloudAlert.max)
                    setTemperature(description: cloudAlert.description, for: physicalSensor)
                case .humidity:
                    // in percent on cloud, in fraction locally
                    type = .relativeHumidity(
                        lower: cloudAlert.min / 100.0,
                        upper: cloudAlert.max / 100.0
                    )
                    setRelativeHumidity(description: cloudAlert.description, for: physicalSensor)
                case .pressure:
                    // in Pa on cloud, in hPa locally
                    type = .pressure(
                        lower: cloudAlert.min / 100.0,
                        upper: cloudAlert.max / 100.0
                    )
                    setPressure(description: cloudAlert.description, for: physicalSensor)
                case .movement:
                    type = .movement(last: cloudAlert.counter)
                    setMovement(description: cloudAlert.description, for: physicalSensor)
                case .signal:
                    type = nil // not on iOS yet
                }
                if let type = type {
                    if cloudAlert.enabled {
                        register(type: type, for: physicalSensor)
                    } else {
                        unregister(type: type, for: physicalSensor)
                    }
                }
            }
        }
    }

    // Physical Sensor
    public func hasRegistrations(for sensor: PhysicalSensor) -> Bool {
        return AlertType.allCases.contains(where: { isOn(type: $0, for: sensor) })
    }

    public func isOn(type: AlertType, for sensor: PhysicalSensor) -> Bool {
        return alert(for: sensor, of: type) != nil
    }

    public func alert(for sensor: PhysicalSensor, of type: AlertType) -> AlertType? {
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

    public func mute(type: AlertType, for sensor: PhysicalSensor, till date: Date) {
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

    public func unmute(type: AlertType, for sensor: PhysicalSensor) {
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

    public func mutedTill(type: AlertType, for sensor: PhysicalSensor) -> Date? {
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
    public func hasRegistrations(for sensor: VirtualSensor) -> Bool {
        return AlertType.allCases.contains(where: { isOn(type: $0, for: sensor) })
    }

    public func isOn(type: AlertType, for sensor: VirtualSensor) -> Bool {
        return alert(for: sensor, of: type) != nil
    }

    public func alert(for sensor: VirtualSensor, of type: AlertType) -> AlertType? {
        return alertPersistence.alert(for: sensor.id, of: type)
    }

    public func mutedTill(type: AlertType, for sensor: VirtualSensor) -> Date? {
        alertPersistence.mutedTill(type: type, for: sensor.id)
    }

    public func register(type: AlertType, for sensor: VirtualSensor) {
        alertPersistence.register(type: type, for: sensor.id)
        postAlertDidChange(with: sensor, of: type)
    }

    public func unregister(type: AlertType, for sensor: VirtualSensor) {
        alertPersistence.unregister(type: type, for: sensor.id)
        postAlertDidChange(with: sensor, of: type)
    }

    public func mute(type: AlertType, for sensor: VirtualSensor, till date: Date) {
        alertPersistence.mute(type: type, for: sensor.id, till: date)
        postAlertDidChange(with: sensor, of: type)
    }

    public func unmute(type: AlertType, for sensor: VirtualSensor) {
        alertPersistence.unmute(type: type, for: sensor.id)
        postAlertDidChange(with: sensor, of: type)
    }

    // UUID
    func hasRegistrations(for uuid: String) -> Bool {
        return AlertType.allCases.contains(where: { isOn(type: $0, for: uuid) })
    }

    public func isOn(type: AlertType, for uuid: String) -> Bool {
        return alert(for: uuid, of: type) != nil
    }

    public func alert(for uuid: String, of type: AlertType) -> AlertType? {
        return alertPersistence.alert(for: uuid, of: type)
    }

    public func mutedTill(type: AlertType, for uuid: String) -> Date? {
        alertPersistence.mutedTill(type: type, for: uuid)
    }

    private func postAlertDidChange(with sensor: PhysicalSensor, of type: AlertType) {
        NotificationCenter
            .default
            .post(
                name: .RuuviServiceAlertDidChange,
                object: nil,
                userInfo: [
                    RuuviServiceAlertDidChangeKey.physicalSensor: sensor,
                    RuuviServiceAlertDidChangeKey.type: type
                ]
            )
    }

    private func postAlertDidChange(with sensor: VirtualSensor, of type: AlertType) {
        NotificationCenter
            .default
            .post(
                name: .RuuviServiceAlertDidChange,
                object: nil,
                userInfo: [
                    RuuviServiceAlertDidChangeKey.virtualSensor: sensor,
                    RuuviServiceAlertDidChangeKey.type: type
                ]
            )
    }
}

// MARK: - Temperature
extension RuuviServiceAlertImpl {
    public func lowerCelsius(for sensor: PhysicalSensor) -> Double? {
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

    public func setLower(celsius: Double?, for sensor: PhysicalSensor) {
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

    public func upperCelsius(for sensor: PhysicalSensor) -> Double? {
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

    public func setUpper(celsius: Double?, for sensor: PhysicalSensor) {
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

    public func temperatureDescription(for sensor: PhysicalSensor) -> String? {
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

    public func setTemperature(description: String?, for sensor: PhysicalSensor) {
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

    public func lowerCelsius(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.lowerCelsius(for: sensor.id)
    }

    public func setLower(celsius: Double?, for sensor: VirtualSensor) {
        alertPersistence.setLower(celsius: celsius, for: sensor.id)
        if let l = celsius, let u = upperCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }

    public func upperCelsius(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.upperCelsius(for: sensor.id)
    }

    public func setUpper(celsius: Double?, for sensor: VirtualSensor) {
        alertPersistence.setUpper(celsius: celsius, for: sensor.id)
        if let u = celsius, let l = lowerCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }

    public func temperatureDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.temperatureDescription(for: sensor.id)
    }

    public func setTemperature(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setTemperature(description: description, for: sensor.id)
        if let l = lowerCelsius(for: sensor), let u = upperCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }

    public func lowerCelsius(for uuid: String) -> Double? {
        return alertPersistence.lowerCelsius(for: uuid)
    }

    public func upperCelsius(for uuid: String) -> Double? {
        return alertPersistence.upperCelsius(for: uuid)
    }

    public func temperatureDescription(for uuid: String) -> String? {
        return alertPersistence.temperatureDescription(for: uuid)
    }
}

// MARK: - Relative Humidity
extension RuuviServiceAlertImpl {
    public func lowerRelativeHumidity(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerRelativeHumidity(for: luid.value)
                ?? alertPersistence.lowerRelativeHumidity(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerRelativeHumidity(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerRelativeHumidity(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    public func setLower(relativeHumidity: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(relativeHumidity: relativeHumidity, for: luid.value)
            alertPersistence.setLower(relativeHumidity: relativeHumidity, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(relativeHumidity: relativeHumidity, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(relativeHumidity: relativeHumidity, for: macId.value)
        } else {
            assertionFailure()
        }
        if let l = relativeHumidity, let u = upperRelativeHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .relativeHumidity(lower: l, upper: u))
        }
    }

    public func upperRelativeHumidity(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperRelativeHumidity(for: luid.value)
                ?? alertPersistence.upperRelativeHumidity(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperRelativeHumidity(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperRelativeHumidity(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    public func setUpper(relativeHumidity: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(relativeHumidity: relativeHumidity, for: luid.value)
            alertPersistence.setUpper(relativeHumidity: relativeHumidity, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(relativeHumidity: relativeHumidity, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(relativeHumidity: relativeHumidity, for: macId.value)
        } else {
            assertionFailure()
        }
        if let u = relativeHumidity, let l = lowerRelativeHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .relativeHumidity(lower: l, upper: u))
        }
    }

    public func relativeHumidityDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.relativeHumidityDescription(for: luid.value)
                ?? alertPersistence.relativeHumidityDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.relativeHumidityDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.relativeHumidityDescription(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    public func setRelativeHumidity(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setRelativeHumidity(description: description, for: luid.value)
            alertPersistence.setRelativeHumidity(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setRelativeHumidity(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setRelativeHumidity(description: description, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = lowerRelativeHumidity(for: sensor), let u = upperRelativeHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .relativeHumidity(lower: l, upper: u))
        }
    }

    public func lowerRelativeHumidity(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.lowerRelativeHumidity(for: sensor.id)
    }

    public func setLower(relativeHumidity: Double?, for sensor: VirtualSensor) {
        alertPersistence.setLower(relativeHumidity: relativeHumidity, for: sensor.id)
        if let l = relativeHumidity, let u = upperRelativeHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .relativeHumidity(lower: l, upper: u))
        }
    }

    public func upperRelativeHumidity(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.upperRelativeHumidity(for: sensor.id)
    }

    public func setUpper(relativeHumidity: Double?, for sensor: VirtualSensor) {
        alertPersistence.setUpper(relativeHumidity: relativeHumidity, for: sensor.id)
        if let u = relativeHumidity, let l = lowerRelativeHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .relativeHumidity(lower: l, upper: u))
        }
    }

    public func relativeHumidityDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.relativeHumidityDescription(for: sensor.id)
    }

    public func setRelativeHumidity(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setRelativeHumidity(description: description, for: sensor.id)
        if let l = lowerRelativeHumidity(for: sensor), let u = upperRelativeHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .relativeHumidity(lower: l, upper: u))
        }
    }

    public func lowerRelativeHumidity(for uuid: String) -> Double? {
        return alertPersistence.lowerRelativeHumidity(for: uuid)
    }

    public func upperRelativeHumidity(for uuid: String) -> Double? {
        return alertPersistence.upperRelativeHumidity(for: uuid)
    }

    public func relativeHumidityDescription(for uuid: String) -> String? {
        return alertPersistence.relativeHumidityDescription(for: uuid)
    }
}

// MARK: - Humidity
extension RuuviServiceAlertImpl {
    public func lowerHumidity(for sensor: PhysicalSensor) -> Humidity? {
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

    public func setLower(humidity: Humidity?, for sensor: PhysicalSensor) {
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

    public func upperHumidity(for sensor: PhysicalSensor) -> Humidity? {
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

    public func setUpper(humidity: Humidity?, for sensor: PhysicalSensor) {
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

    public func humidityDescription(for sensor: PhysicalSensor) -> String? {
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

    public func setHumidity(description: String?, for sensor: PhysicalSensor) {
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

    public func lowerHumidity(for sensor: VirtualSensor) -> Humidity? {
        return alertPersistence.lowerHumidity(for: sensor.id)
    }

    public func setLower(humidity: Humidity?, for sensor: VirtualSensor) {
        alertPersistence.setLower(humidity: humidity, for: sensor.id)
        if let l = humidity, let u = upperHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .humidity(lower: l, upper: u))
        }
    }

    public func upperHumidity(for sensor: VirtualSensor) -> Humidity? {
        return alertPersistence.upperHumidity(for: sensor.id)
    }

    public func setUpper(humidity: Humidity?, for sensor: VirtualSensor) {
        alertPersistence.setUpper(humidity: humidity, for: sensor.id)
        if let u = humidity, let l = lowerHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .humidity(lower: l, upper: u))
        }
    }

    public func humidityDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.humidityDescription(for: sensor.id)
    }

    public func setHumidity(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setHumidity(description: description, for: sensor.id)
        if let l = lowerHumidity(for: sensor),
           let u = upperHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .humidity(lower: l, upper: u))
        }
    }

    public func lowerHumidity(for uuid: String) -> Humidity? {
        return alertPersistence.lowerHumidity(for: uuid)
    }

    public func upperHumidity(for uuid: String) -> Humidity? {
        return alertPersistence.upperHumidity(for: uuid)
    }

    public func humidityDescription(for uuid: String) -> String? {
        return alertPersistence.humidityDescription(for: uuid)
    }
}

// MARK: - Dew Point
extension RuuviServiceAlertImpl {
    public func lowerDewPointCelsius(for sensor: PhysicalSensor) -> Double? {
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

    public func setLowerDewPoint(celsius: Double?, for sensor: PhysicalSensor) {
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

    public func upperDewPointCelsius(for sensor: PhysicalSensor) -> Double? {
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

    public func setUpperDewPoint(celsius: Double?, for sensor: PhysicalSensor) {
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

    public func dewPointDescription(for sensor: PhysicalSensor) -> String? {
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

    public func setDewPoint(description: String?, for sensor: PhysicalSensor) {
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

    public func lowerDewPointCelsius(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.lowerDewPointCelsius(for: sensor.id)
    }

    public func setLowerDewPoint(celsius: Double?, for sensor: VirtualSensor) {
        alertPersistence.setLowerDewPoint(celsius: celsius, for: sensor.id)
        if let l = celsius, let u = upperDewPointCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }

    public func upperDewPointCelsius(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.upperDewPointCelsius(for: sensor.id)
    }

    public func setUpperDewPoint(celsius: Double?, for sensor: VirtualSensor) {
        alertPersistence.setUpperDewPoint(celsius: celsius, for: sensor.id)
        if let u = celsius, let l = lowerDewPointCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }

    public func dewPointDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.dewPointDescription(for: sensor.id)
    }

    public func setDewPoint(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setDewPoint(description: description, for: sensor.id)
        if let l = lowerDewPointCelsius(for: sensor), let u = upperDewPointCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }

    public func lowerDewPointCelsius(for uuid: String) -> Double? {
        return alertPersistence.lowerDewPointCelsius(for: uuid)
    }

    public func upperDewPointCelsius(for uuid: String) -> Double? {
        return alertPersistence.upperDewPointCelsius(for: uuid)
    }

    public func dewPointDescription(for uuid: String) -> String? {
        return alertPersistence.dewPointDescription(for: uuid)
    }
}

// MARK: - Pressure
extension RuuviServiceAlertImpl {
    public func lowerPressure(for sensor: PhysicalSensor) -> Double? {
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

    public func setLower(pressure: Double?, for sensor: PhysicalSensor) {
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

    public func upperPressure(for sensor: PhysicalSensor) -> Double? {
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

    public func setUpper(pressure: Double?, for sensor: PhysicalSensor) {
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

    public func pressureDescription(for sensor: PhysicalSensor) -> String? {
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

    public func setPressure(description: String?, for sensor: PhysicalSensor) {
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

    public func lowerPressure(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.lowerPressure(for: sensor.id)
    }

    public func setLower(pressure: Double?, for sensor: VirtualSensor) {
        alertPersistence.setLower(pressure: pressure, for: sensor.id)
        if let l = pressure, let u = upperPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }

    public func upperPressure(for sensor: VirtualSensor) -> Double? {
        return alertPersistence.upperPressure(for: sensor.id)
    }

    public func setUpper(pressure: Double?, for sensor: VirtualSensor) {
        alertPersistence.setUpper(pressure: pressure, for: sensor.id)
        if let u = pressure, let l = lowerPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }

    public func pressureDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.pressureDescription(for: sensor.id)
    }

    public func setPressure(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setPressure(description: description, for: sensor.id)
        if let l = lowerPressure(for: sensor), let u = upperPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }

    public func lowerPressure(for uuid: String) -> Double? {
        return alertPersistence.lowerPressure(for: uuid)
    }

    public func upperPressure(for uuid: String) -> Double? {
        return alertPersistence.upperPressure(for: uuid)
    }

    public func pressureDescription(for uuid: String) -> String? {
        return alertPersistence.pressureDescription(for: uuid)
    }
}

// MARK: - Connection
extension RuuviServiceAlertImpl {
    public func connectionDescription(for sensor: PhysicalSensor) -> String? {
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

    public func setConnection(description: String?, for sensor: PhysicalSensor) {
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

    public func connectionDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.connectionDescription(for: sensor.id)
    }

    public func setConnection(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setConnection(description: description, for: sensor.id)
        postAlertDidChange(with: sensor, of: .connection)
    }

    public func connectionDescription(for uuid: String) -> String? {
        return alertPersistence.connectionDescription(for: uuid)
    }
}

// MARK: - Movement
extension RuuviServiceAlertImpl {
    public func movementCounter(for sensor: PhysicalSensor) -> Int? {
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

    public func setMovement(counter: Int?, for sensor: PhysicalSensor) {
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

    public func movementDescription(for sensor: PhysicalSensor) -> String? {
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

    public func setMovement(description: String?, for sensor: PhysicalSensor) {
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

    public func movementCounter(for sensor: VirtualSensor) -> Int? {
        return alertPersistence.movementCounter(for: sensor.id)
    }

    public func setMovement(counter: Int?, for sensor: VirtualSensor) {
        alertPersistence.setMovement(counter: counter, for: sensor.id)
        // no need to post an update, this is not user initiated action
    }

    public func movementDescription(for sensor: VirtualSensor) -> String? {
        return alertPersistence.movementDescription(for: sensor.id)
    }

    public func setMovement(description: String?, for sensor: VirtualSensor) {
        alertPersistence.setMovement(description: description, for: sensor.id)
        if let c = movementCounter(for: sensor) {
            postAlertDidChange(with: sensor, of: .movement(last: c))
        }
    }

    public func movementCounter(for uuid: String) -> Int? {
        return alertPersistence.movementCounter(for: uuid)
    }

    public func setMovement(counter: Int?, for uuid: String) {
        alertPersistence.setMovement(counter: counter, for: uuid)
        // no need to post an update, this is not user initiated action
    }

    public func movementDescription(for uuid: String) -> String? {
        return alertPersistence.movementDescription(for: uuid)
    }
}
// swiftlint:enable file_length
