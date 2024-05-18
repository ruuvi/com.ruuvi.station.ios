// swiftlint:disable file_length
import Foundation
import Future
import RuuviCloud
import RuuviLocal
import RuuviOntology

// MARK: - RuuviTag

public extension RuuviServiceAlertImpl {
    // swiftlint:disable:next function_body_length
    func register(type: AlertType, ruuviTag: RuuviTagSensor) {
        register(type: type, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            switch type {
            case let .temperature(lower, upper):
                cloud.setAlert(
                    type: .temperature,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: temperatureDescription(for: ruuviTag),
                    for: macId
                )
            case let .relativeHumidity(lower, upper):
                cloud.setAlert(
                    type: .humidity,
                    settingType: .state,
                    isEnabled: true,
                    min: lower * 100.0, // in percent on cloud, fraction locally
                    max: upper * 100.0, // in percent on cloud, fraction locally
                    counter: nil,
                    delay: nil,
                    description: relativeHumidityDescription(for: ruuviTag),
                    for: macId
                )
            case .humidity:
                break // absolute is not on cloud yet (11.06.2021)
            case let .pressure(lower, upper):
                cloud.setAlert(
                    type: .pressure,
                    settingType: .state,
                    isEnabled: true,
                    min: lower * 100, // in Pa on cloud, in hPa locally
                    max: upper * 100, // in Pa on cloud, in hPa locally
                    counter: nil,
                    delay: nil,
                    description: pressureDescription(for: ruuviTag),
                    for: macId
                )
            case let .signal(lower, upper):
                cloud.setAlert(
                    type: .signal,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: signalDescription(for: ruuviTag),
                    for: macId
                )
            case .connection:
                break
            case let .cloudConnection(unseenDuration):
                cloud.setAlert(
                    type: .offline,
                    settingType: .state,
                    isEnabled: true,
                    min: 0,
                    max: unseenDuration,
                    counter: nil,
                    delay: 0,
                    description: cloudConnectionDescription(for: ruuviTag),
                    for: macId
                )
            case let .movement(last):
                cloud.setAlert(
                    type: .movement,
                    settingType: .state,
                    isEnabled: true,
                    min: nil,
                    max: nil,
                    counter: last,
                    delay: nil,
                    description: movementDescription(for: ruuviTag),
                    for: macId
                )
            }
        }
    }

    // swiftlint:disable:next function_body_length
    func unregister(type: AlertType, ruuviTag: RuuviTagSensor) {
        unregister(type: type, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            switch type {
            case let .temperature(lower, upper):
                cloud.setAlert(
                    type: .temperature,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: temperatureDescription(for: ruuviTag),
                    for: macId
                )
            case let .relativeHumidity(lower, upper):
                cloud.setAlert(
                    type: .humidity,
                    settingType: .state,
                    isEnabled: false,
                    min: lower * 100, // in percent on cloud, fraction locally
                    max: upper * 100, // in percent on cloud, fraction locally
                    counter: nil,
                    delay: nil,
                    description: relativeHumidityDescription(for: ruuviTag),
                    for: macId
                )
            case .humidity:
                break // absolute is not on cloud yet (11.06.2021)
            case let .pressure(lower, upper):
                cloud.setAlert(
                    type: .pressure,
                    settingType: .state,
                    isEnabled: false,
                    min: lower * 100, // in Pa on cloud, in hPa locally
                    max: upper * 100, // in Pa on cloud, in hPa locally
                    counter: nil,
                    delay: nil,
                    description: pressureDescription(for: ruuviTag),
                    for: macId
                )
            case let .signal(lower, upper):
                cloud.setAlert(
                    type: .signal,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: signalDescription(for: ruuviTag),
                    for: macId
                )
            case .connection:
                break
            case let .cloudConnection(unseenDuration):
                cloud.setAlert(
                    type: .offline,
                    settingType: .state,
                    isEnabled: false,
                    min: 0,
                    max: unseenDuration,
                    counter: nil,
                    delay: 0,
                    description: cloudConnectionDescription(for: ruuviTag),
                    for: macId
                )
            case let .movement(last):
                cloud.setAlert(
                    type: .movement,
                    settingType: .state,
                    isEnabled: false,
                    min: nil,
                    max: nil,
                    counter: last,
                    delay: nil,
                    description: movementDescription(for: ruuviTag),
                    for: macId
                )
            }
        }
    }

    func setLower(celsius: Double?, ruuviTag: RuuviTagSensor) {
        setLower(celsius: celsius, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .temperature,
                settingType: .lowerBound,
                isEnabled: isOn(type: .temperature(lower: 0, upper: 0), for: ruuviTag),
                min: celsius,
                max: upperCelsius(for: ruuviTag),
                counter: nil,
                delay: nil,
                description: temperatureDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(celsius: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(celsius: celsius, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .temperature,
                settingType: .upperBound,
                isEnabled: isOn(type: .temperature(lower: 0, upper: 0), for: ruuviTag),
                min: lowerCelsius(for: ruuviTag),
                max: celsius,
                counter: nil,
                delay: nil,
                description: temperatureDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setTemperature(description: String?, ruuviTag: RuuviTagSensor) {
        setTemperature(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .temperature,
                settingType: .description,
                isEnabled: isOn(type: .temperature(lower: 0, upper: 0), for: ruuviTag),
                min: lowerCelsius(for: ruuviTag),
                max: upperCelsius(for: ruuviTag),
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    func setLower(relativeHumidity: Double?, ruuviTag: RuuviTagSensor) {
        setLower(relativeHumidity: relativeHumidity, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .humidity,
                settingType: .lowerBound,
                isEnabled: isOn(type: .relativeHumidity(lower: 0, upper: 0), for: ruuviTag),
                min: (relativeHumidity ?? 0) * 100.0,
                max: (upperRelativeHumidity(for: ruuviTag) ?? 0) * 100.0,
                counter: nil,
                delay: nil,
                description: relativeHumidityDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(relativeHumidity: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(relativeHumidity: relativeHumidity, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .humidity,
                settingType: .upperBound,
                isEnabled: isOn(type: .relativeHumidity(lower: 0, upper: 0), for: ruuviTag),
                min: (lowerRelativeHumidity(for: ruuviTag) ?? 0) * 100.0,
                max: (relativeHumidity ?? 0) * 100.0,
                counter: nil,
                delay: nil,
                description: relativeHumidityDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setRelativeHumidity(description: String?, ruuviTag: RuuviTagSensor) {
        setRelativeHumidity(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .humidity,
                settingType: .description,
                isEnabled: isOn(type: .relativeHumidity(lower: 0, upper: 0), for: ruuviTag),
                min: (lowerRelativeHumidity(for: ruuviTag) ?? 0) * 100.0,
                max: (upperRelativeHumidity(for: ruuviTag) ?? 0) * 100.0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    func setLower(pressure: Double?, ruuviTag: RuuviTagSensor) {
        setLower(pressure: pressure, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pressure,
                settingType: .lowerBound,
                isEnabled: isOn(type: .pressure(lower: 0, upper: 0), for: ruuviTag),
                min: (pressure ?? 0) * 100.0,
                max: (upperPressure(for: ruuviTag) ?? 0) * 100.0,
                counter: nil,
                delay: nil,
                description: pressureDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(pressure: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(pressure: pressure, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pressure,
                settingType: .upperBound,
                isEnabled: isOn(type: .pressure(lower: 0, upper: 0), for: ruuviTag),
                min: (lowerPressure(for: ruuviTag) ?? 0) * 100.0,
                max: (pressure ?? 0) * 100.0,
                counter: nil,
                delay: nil,
                description: pressureDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setPressure(description: String?, ruuviTag: RuuviTagSensor) {
        setPressure(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pressure,
                settingType: .description,
                isEnabled: isOn(type: .pressure(lower: 0, upper: 0), for: ruuviTag),
                min: (lowerPressure(for: ruuviTag) ?? 0) * 100.0,
                max: (upperPressure(for: ruuviTag) ?? 0) * 100.0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    func setLower(signal: Double?, ruuviTag: RuuviTagSensor) {
        setLower(signal: signal, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .signal,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .signal(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: signal ?? 0,
                max: upperSignal(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: signalDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(signal: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(signal: signal, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .signal,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .signal(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerSignal(for: ruuviTag) ?? 0,
                max: signal ?? 0,
                counter: nil,
                delay: nil,
                description: signalDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setSignal(description: String?, ruuviTag: RuuviTagSensor) {
        setSignal(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .signal,
                settingType: .description,
                isEnabled: isOn(
                    type: .signal(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerSignal(for: ruuviTag) ?? 0,
                max: upperSignal(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    func setMovement(description: String?, ruuviTag: RuuviTagSensor) {
        setMovement(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .movement,
                settingType: .description,
                isEnabled: isOn(type: .movement(last: 0), for: ruuviTag),
                min: nil,
                max: nil,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    func setCloudConnection(unseenDuration: Double?, ruuviTag: RuuviTagSensor) {
        setCloudConnection(unseenDuration: unseenDuration, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .offline,
                settingType: .delay,
                isEnabled: isOn(type: .cloudConnection(unseenDuration: 0), for: ruuviTag),
                min: 0,
                max: unseenDuration,
                counter: nil,
                delay: 0,
                description: cloudConnectionDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setCloudConnection(description: String?, ruuviTag: RuuviTagSensor) {
        setCloudConnection(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .offline,
                settingType: .description,
                isEnabled: isOn(type: .cloudConnection(unseenDuration: 0), for: ruuviTag),
                min: 0,
                max: cloudConnectionUnseenDuration(for: ruuviTag) ?? 600, // Default: 15mins
                counter: nil,
                delay: 0,
                description: description,
                for: macId
            )
        }
    }
}

// swiftlint:disable:next type_body_length
public final class RuuviServiceAlertImpl: RuuviServiceAlert {
    private let cloud: RuuviCloud
    private let alertPersistence: AlertPersistence
    private let localIDs: RuuviLocalIDs
    private var ruuviLocalSettings: RuuviLocalSettings

    public init(
        cloud: RuuviCloud,
        localIDs: RuuviLocalIDs,
        ruuviLocalSettings: RuuviLocalSettings
    ) {
        self.cloud = cloud
        self.localIDs = localIDs
        self.ruuviLocalSettings = ruuviLocalSettings
        alertPersistence = AlertPersistenceUserDefaults()
    }

    // RuuviCloudAlert
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func sync(cloudAlerts: [RuuviCloudSensorAlerts]) {
        cloudAlerts.forEach { cloudSensorAlert in
            guard let macId = cloudSensorAlert.sensor?.mac else { return }
            let luid = localIDs.luid(for: macId)
            let physicalSensor = PhysicalSensorStruct(luid: luid, macId: macId)
            cloudSensorAlert.alerts?.forEach { cloudAlert in
                var type: AlertType?
                switch cloudAlert.type {
                case .temperature:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    // This sets the increased limit for external sensor when synced to cloud
                    // data.
                    let temperatureUnit = ruuviLocalSettings.temperatureUnit
                    let standardMinmimumBound = temperatureUnit.alertRange.lowerBound
                    let standardMaximumBound = temperatureUnit.alertRange.upperBound
                    if min < standardMinmimumBound || max > standardMaximumBound {
                        ruuviLocalSettings.setShowCustomTempAlertBound(for: physicalSensor.id)
                    }

                    type = .temperature(lower: min, upper: max)
                    setTemperature(description: cloudAlert.description, for: physicalSensor)
                case .humidity:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    // in percent on cloud, in fraction locally
                    type = .relativeHumidity(
                        lower: min / 100.0,
                        upper: max / 100.0
                    )
                    setRelativeHumidity(description: cloudAlert.description, for: physicalSensor)
                case .pressure:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    // in Pa on cloud, in hPa locally
                    type = .pressure(
                        lower: min / 100.0,
                        upper: max / 100.0
                    )
                    setPressure(description: cloudAlert.description, for: physicalSensor)
                case .movement:
                    guard let counter = cloudAlert.counter else { return }
                    type = .movement(last: counter)
                    setMovement(description: cloudAlert.description, for: physicalSensor)
                case .signal:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .signal(
                        lower: min,
                        upper: max
                    )
                    setSignal(description: cloudAlert.description, for: physicalSensor)
                case .offline:
                    guard let unseenDuration = cloudAlert.max else { return }
                    type = .cloudConnection(unseenDuration: unseenDuration)
                    setCloudConnection(description: cloudAlert.description, for: physicalSensor)
                default:
                    break
                }
                if let type {
                    if let enabled = cloudAlert.enabled, enabled {
                        register(type: type, for: physicalSensor)
                        trigger(
                            type: type,
                            trigerred: cloudAlert.triggered,
                            trigerredAt: cloudAlert.triggeredAt,
                            for: physicalSensor
                        )
                    } else {
                        unregister(type: type, for: physicalSensor)
                    }
                }
            }
        }
    }

    // Physical Sensor
    public func hasRegistrations(for sensor: PhysicalSensor) -> Bool {
        AlertType.allCases.contains(where: { isOn(type: $0, for: sensor) })
    }

    public func isOn(type: AlertType, for sensor: PhysicalSensor) -> Bool {
        alert(for: sensor, of: type) != nil
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

    public func remove(type: AlertType, ruuviTag: RuuviTagSensor) {
        if let luid = ruuviTag.luid, let macId = ruuviTag.macId {
            alertPersistence.remove(type: type, for: luid.value)
            alertPersistence.remove(type: type, for: macId.value)
        } else if let luid = ruuviTag.luid {
            alertPersistence.remove(type: type, for: luid.value)
        } else if let macId = ruuviTag.macId {
            alertPersistence.remove(type: type, for: macId.value)
        } else {
            assertionFailure()
        }
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

    public func trigger(
        type: AlertType,
        trigerred: Bool?,
        trigerredAt: String?,
        for sensor: PhysicalSensor
    ) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.trigger(
                type: type,
                trigerred: trigerred,
                trigerredAt: trigerredAt,
                for: luid.value
            )
            alertPersistence.trigger(
                type: type,
                trigerred: trigerred,
                trigerredAt: trigerredAt,
                for: macId.value
            )
        } else if let luid = sensor.luid {
            alertPersistence.trigger(
                type: type,
                trigerred: trigerred,
                trigerredAt: trigerredAt,
                for: luid.value
            )
        } else if let macId = sensor.macId {
            alertPersistence.trigger(
                type: type,
                trigerred: trigerred,
                trigerredAt: trigerredAt,
                for: macId.value
            )
        } else {
            assertionFailure()
        }
        postAlertTriggerDidChange(with: sensor, of: type)
    }

    public func triggered(
        for sensor: PhysicalSensor,
        of type: AlertType
    ) -> Bool? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.triggered(for: luid.value, of: type)
                ?? alertPersistence.triggered(for: macId.value, of: type)
        } else if let luid = sensor.luid {
            return alertPersistence.triggered(for: luid.value, of: type)
        } else if let macId = sensor.macId {
            return alertPersistence.triggered(for: macId.value, of: type)
        } else {
            assertionFailure()
            return nil
        }
    }

    public func triggeredAt(
        for sensor: PhysicalSensor,
        of type: AlertType
    ) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.triggeredAt(for: luid.value, of: type)
                ?? alertPersistence.triggeredAt(for: macId.value, of: type)
        } else if let luid = sensor.luid {
            return alertPersistence.triggeredAt(for: luid.value, of: type)
        } else if let macId = sensor.macId {
            return alertPersistence.triggeredAt(for: macId.value, of: type)
        } else {
            assertionFailure()
            return nil
        }
    }

    // UUID
    func hasRegistrations(for uuid: String) -> Bool {
        AlertType.allCases.contains(where: { isOn(type: $0, for: uuid) })
    }

    public func isOn(type: AlertType, for uuid: String) -> Bool {
        alert(for: uuid, of: type) != nil
    }

    public func alert(for uuid: String, of type: AlertType) -> AlertType? {
        alertPersistence.alert(for: uuid, of: type)
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
                    RuuviServiceAlertDidChangeKey.type: type,
                ]
            )
    }

    private func postAlertTriggerDidChange(with sensor: PhysicalSensor, of type: AlertType) {
        NotificationCenter
            .default
            .post(
                name: .RuuviServiceAlertTriggerDidChange,
                object: nil,
                userInfo: [
                    RuuviServiceAlertDidChangeKey.physicalSensor: sensor,
                    RuuviServiceAlertDidChangeKey.type: type,
                ]
            )
    }
}

// MARK: - Temperature

public extension RuuviServiceAlertImpl {
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

    func lowerCelsius(for uuid: String) -> Double? {
        alertPersistence.lowerCelsius(for: uuid)
    }

    func upperCelsius(for uuid: String) -> Double? {
        alertPersistence.upperCelsius(for: uuid)
    }

    func temperatureDescription(for uuid: String) -> String? {
        alertPersistence.temperatureDescription(for: uuid)
    }
}

// MARK: - Relative Humidity

public extension RuuviServiceAlertImpl {
    func lowerRelativeHumidity(for sensor: PhysicalSensor) -> Double? {
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

    func setLower(relativeHumidity: Double?, for sensor: PhysicalSensor) {
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

    func upperRelativeHumidity(for sensor: PhysicalSensor) -> Double? {
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

    func setUpper(relativeHumidity: Double?, for sensor: PhysicalSensor) {
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

    func relativeHumidityDescription(for sensor: PhysicalSensor) -> String? {
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

    func setRelativeHumidity(description: String?, for sensor: PhysicalSensor) {
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

    func lowerRelativeHumidity(for uuid: String) -> Double? {
        alertPersistence.lowerRelativeHumidity(for: uuid)
    }

    func upperRelativeHumidity(for uuid: String) -> Double? {
        alertPersistence.upperRelativeHumidity(for: uuid)
    }

    func relativeHumidityDescription(for uuid: String) -> String? {
        alertPersistence.relativeHumidityDescription(for: uuid)
    }
}

// MARK: - Humidity

public extension RuuviServiceAlertImpl {
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

    func lowerHumidity(for uuid: String) -> Humidity? {
        alertPersistence.lowerHumidity(for: uuid)
    }

    func upperHumidity(for uuid: String) -> Humidity? {
        alertPersistence.upperHumidity(for: uuid)
    }

    func humidityDescription(for uuid: String) -> String? {
        alertPersistence.humidityDescription(for: uuid)
    }
}

// MARK: - Pressure

public extension RuuviServiceAlertImpl {
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

    func lowerPressure(for uuid: String) -> Double? {
        alertPersistence.lowerPressure(for: uuid)
    }

    func upperPressure(for uuid: String) -> Double? {
        alertPersistence.upperPressure(for: uuid)
    }

    func pressureDescription(for uuid: String) -> String? {
        alertPersistence.pressureDescription(for: uuid)
    }
}

// MARK: - Signal

public extension RuuviServiceAlertImpl {
    func lowerSignal(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerSignal(for: luid.value)
                ?? alertPersistence.lowerSignal(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerSignal(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerSignal(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setLower(signal: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(signal: signal, for: luid.value)
            alertPersistence.setLower(signal: signal, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(signal: signal, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(signal: signal, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = signal, let u = upperSignal(for: sensor) {
            postAlertDidChange(with: sensor, of: .signal(lower: l, upper: u))
        }
    }

    func upperSignal(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperSignal(for: luid.value)
                ?? alertPersistence.upperSignal(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperSignal(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperSignal(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setUpper(signal: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(signal: signal, for: luid.value)
            alertPersistence.setUpper(signal: signal, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(signal: signal, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(signal: signal, for: macId.value)
        } else {
            assertionFailure()
        }

        if let u = signal, let l = lowerSignal(for: sensor) {
            postAlertDidChange(with: sensor, of: .signal(lower: l, upper: u))
        }
    }

    func signalDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.signalDescription(for: luid.value)
                ?? alertPersistence.signalDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.signalDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.signalDescription(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setSignal(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setSignal(description: description, for: luid.value)
            alertPersistence.setSignal(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setSignal(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setSignal(description: description, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = lowerSignal(for: sensor), let u = upperSignal(for: sensor) {
            postAlertDidChange(with: sensor, of: .signal(lower: l, upper: u))
        }
    }

    func lowerSignal(for uuid: String) -> Double? {
        alertPersistence.lowerSignal(for: uuid)
    }

    func upperSignal(for uuid: String) -> Double? {
        alertPersistence.upperSignal(for: uuid)
    }

    func signalDescription(for uuid: String) -> String? {
        alertPersistence.signalDescription(for: uuid)
    }
}

// MARK: - Connection

public extension RuuviServiceAlertImpl {
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

    func connectionDescription(for uuid: String) -> String? {
        alertPersistence.connectionDescription(for: uuid)
    }
}

// MARK: - Cloud Connection

public extension RuuviServiceAlertImpl {
    func cloudConnectionDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.cloudConnectionDescription(for: luid.value)
                ?? alertPersistence.cloudConnectionDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.cloudConnectionDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.cloudConnectionDescription(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }

    func setCloudConnection(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setCloudConnection(description: description, for: luid.value)
            alertPersistence.setCloudConnection(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setCloudConnection(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setCloudConnection(description: description, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    func setCloudConnection(unseenDuration: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setCloudConnection(unseenDuration: unseenDuration, for: luid.value)
            alertPersistence.setCloudConnection(unseenDuration: unseenDuration, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setCloudConnection(unseenDuration: unseenDuration, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setCloudConnection(unseenDuration: unseenDuration, for: macId.value)
        } else {
            assertionFailure()
        }
        if let unseenDuration {
            postAlertDidChange(with: sensor, of: .cloudConnection(unseenDuration: unseenDuration))
        }
    }

    func cloudConnectionUnseenDuration(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.cloudConnectionUnseenDuration(for: luid.value)
                ?? alertPersistence.cloudConnectionUnseenDuration(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.cloudConnectionUnseenDuration(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.cloudConnectionUnseenDuration(for: macId.value)
        } else {
            assertionFailure()
            return nil
        }
    }
}

// MARK: - Movement

public extension RuuviServiceAlertImpl {
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

    func movementCounter(for uuid: String) -> Int? {
        alertPersistence.movementCounter(for: uuid)
    }

    func setMovement(counter: Int?, for uuid: String) {
        alertPersistence.setMovement(counter: counter, for: uuid)
        // no need to post an update, this is not user initiated action
    }

    func movementDescription(for uuid: String) -> String? {
        alertPersistence.movementDescription(for: uuid)
    }
}

// swiftlint:enable file_length
