// swiftlint:disable file_length
import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology

private struct RuuviCloudAlertBridge {
    private let cloud: RuuviCloud

    init(cloud: RuuviCloud) {
        self.cloud = cloud
    }

    @discardableResult
    // swiftlint:disable:next function_parameter_count
    func setAlert(
        type: RuuviCloudAlertType,
        settingType: RuuviCloudAlertSettingType,
        isEnabled: Bool,
        min: Double?,
        max: Double?,
        counter: Int?,
        delay: Int?,
        description: String?,
        for macId: MACIdentifier
    ) -> Task<Void, Never> {
        Task {
            try? await cloud.setAlert(
                type: type,
                settingType: settingType,
                isEnabled: isEnabled,
                min: min,
                max: max,
                counter: counter,
                delay: delay,
                description: description,
                for: macId
            )
        }
    }
}

private extension PhysicalSensor {
    var alertIdentifierValues: [String] {
        var values = [String]()
        if let luid {
            values.append(luid.value)
        }
        if let macId,
           !values.contains(macId.value) {
            values.append(macId.value)
        }
        return values
    }
}

private extension RuuviServiceAlertImpl {
    func alertIdentifierValue<Value>(
        for sensor: PhysicalSensor,
        _ read: (String) -> Value?
    ) -> Value? {
        for identifier in sensor.alertIdentifierValues {
            if let value = read(identifier) {
                return value
            }
        }
        return nil
    }

    func updateAlertIdentifiers(
        for sensor: PhysicalSensor,
        _ update: (String) -> Void
    ) {
        sensor.alertIdentifierValues.forEach(update)
    }
}

// MARK: - RuuviTag

public extension RuuviServiceAlertImpl {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
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
            case let .humidity(lower, upper):
                let lowerValue = lower.converted(to: .absolute).value
                let upperValue = upper.converted(to: .absolute).value
                cloud.setAlert(
                    type: .humidityAbsolute,
                    settingType: .state,
                    isEnabled: true,
                    min: lowerValue,
                    max: upperValue,
                    counter: nil,
                    delay: nil,
                    description: humidityDescription(for: ruuviTag),
                    for: macId
                )
            case let .dewPoint(lower, upper):
                cloud.setAlert(
                    type: .dewPoint,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: dewPointDescription(for: ruuviTag),
                    for: macId
                )
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
            case let .batteryVoltage(lower, upper):
                cloud.setAlert(
                    type: .battery,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: batteryVoltageDescription(for: ruuviTag),
                    for: macId
                )
            case let .aqi(lower, upper):
                cloud.setAlert(
                    type: .aqi,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: aqiDescription(for: ruuviTag),
                    for: macId
                )
            case let .carbonDioxide(lower, upper):
                cloud.setAlert(
                    type: .co2,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: carbonDioxideDescription(for: ruuviTag),
                    for: macId
                )
            case let .pMatter1(lower, upper):
                cloud.setAlert(
                    type: .pm10,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: pm1Description(for: ruuviTag),
                    for: macId
                )
            case let .pMatter25(lower, upper):
                cloud.setAlert(
                    type: .pm25,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: pm25Description(for: ruuviTag),
                    for: macId
                )
            case let .pMatter4(lower, upper):
                cloud.setAlert(
                    type: .pm40,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: pm4Description(for: ruuviTag),
                    for: macId
                )
            case let .pMatter10(lower, upper):
                cloud.setAlert(
                    type: .pm100,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: pm10Description(for: ruuviTag),
                    for: macId
                )
            case let .voc(lower, upper):
                cloud.setAlert(
                    type: .voc,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: vocDescription(for: ruuviTag),
                    for: macId
                )
            case let .nox(lower, upper):
                cloud.setAlert(
                    type: .nox,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: noxDescription(for: ruuviTag),
                    for: macId
                )
            case let .soundInstant(lower, upper):
                cloud.setAlert(
                    type: .soundInstant,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: soundInstantDescription(for: ruuviTag),
                    for: macId
                )
            case let .soundAverage(lower, upper):
                cloud.setAlert(
                    type: .soundAverage,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: soundAverageDescription(for: ruuviTag),
                    for: macId
                )
            case let .soundPeak(lower, upper):
                cloud.setAlert(
                    type: .soundPeak,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: soundPeakDescription(for: ruuviTag),
                    for: macId
                )
            case let .luminosity(lower, upper):
                cloud.setAlert(
                    type: .luminosity,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: luminosityDescription(for: ruuviTag),
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
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
            case let .humidity(lower, upper):
                let lowerValue = lower.converted(to: .absolute).value
                let upperValue = upper.converted(to: .absolute).value
                cloud.setAlert(
                    type: .humidityAbsolute,
                    settingType: .state,
                    isEnabled: false,
                    min: lowerValue,
                    max: upperValue,
                    counter: nil,
                    delay: nil,
                    description: humidityDescription(for: ruuviTag),
                    for: macId
                )
            case let .dewPoint(lower, upper):
                cloud.setAlert(
                    type: .dewPoint,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: dewPointDescription(for: ruuviTag),
                    for: macId
                )
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
            case let .batteryVoltage(lower, upper):
                cloud.setAlert(
                    type: .battery,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: batteryVoltageDescription(for: ruuviTag),
                    for: macId
                )
            case let .aqi(lower, upper):
                cloud.setAlert(
                    type: .aqi,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: aqiDescription(for: ruuviTag),
                    for: macId
                )
            case let .carbonDioxide(lower, upper):
                cloud.setAlert(
                    type: .co2,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: carbonDioxideDescription(for: ruuviTag),
                    for: macId
                )
            case let .pMatter1(lower, upper):
                cloud.setAlert(
                    type: .pm10,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: pm1Description(for: ruuviTag),
                    for: macId
                )
            case let .pMatter25(lower, upper):
                cloud.setAlert(
                    type: .pm25,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: pm25Description(for: ruuviTag),
                    for: macId
                )
            case let .pMatter4(lower, upper):
                cloud.setAlert(
                    type: .pm40,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: pm4Description(for: ruuviTag),
                    for: macId
                )
            case let .pMatter10(lower, upper):
                cloud.setAlert(
                    type: .pm100,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: pm10Description(for: ruuviTag),
                    for: macId
                )
            case let .voc(lower, upper):
                cloud.setAlert(
                    type: .voc,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: vocDescription(for: ruuviTag),
                    for: macId
                )
            case let .nox(lower, upper):
                cloud.setAlert(
                    type: .nox,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: noxDescription(for: ruuviTag),
                    for: macId
                )
            case let .soundInstant(lower, upper):
                cloud.setAlert(
                    type: .soundInstant,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: soundInstantDescription(for: ruuviTag),
                    for: macId
                )
            case let .soundAverage(lower, upper):
                cloud.setAlert(
                    type: .soundAverage,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: soundAverageDescription(for: ruuviTag),
                    for: macId
                )
            case let .soundPeak(lower, upper):
                cloud.setAlert(
                    type: .soundPeak,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: soundPeakDescription(for: ruuviTag),
                    for: macId
                )
            case let .luminosity(lower, upper):
                cloud.setAlert(
                    type: .luminosity,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: luminosityDescription(for: ruuviTag),
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

    // MARK: - Temperature
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

    // MARK: - RH
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

    // MARK: - Dew Point
    func setLower(dewPoint: Double?, ruuviTag: RuuviTagSensor) {
        setLower(dewPoint: dewPoint, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .dewPoint,
                settingType: .lowerBound,
                isEnabled: isOn(type: .dewPoint(lower: 0, upper: 0), for: ruuviTag),
                min: dewPoint,
                max: upperDewPoint(for: ruuviTag),
                counter: nil,
                delay: nil,
                description: dewPointDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(dewPoint: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(dewPoint: dewPoint, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .dewPoint,
                settingType: .upperBound,
                isEnabled: isOn(type: .dewPoint(lower: 0, upper: 0), for: ruuviTag),
                min: lowerDewPoint(for: ruuviTag),
                max: dewPoint,
                counter: nil,
                delay: nil,
                description: dewPointDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setDewPoint(description: String?, ruuviTag: RuuviTagSensor) {
        setDewPoint(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .dewPoint,
                settingType: .description,
                isEnabled: isOn(type: .dewPoint(lower: 0, upper: 0), for: ruuviTag),
                min: lowerDewPoint(for: ruuviTag),
                max: upperDewPoint(for: ruuviTag),
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - Pressure
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

    // MARK: - Signal
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

    // MARK: - Battery Voltage
    func setLower(batteryVoltage: Double?, ruuviTag: RuuviTagSensor) {
        setLower(batteryVoltage: batteryVoltage, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .battery,
                settingType: .lowerBound,
                isEnabled: isOn(type: .batteryVoltage(lower: 0, upper: 0), for: ruuviTag),
                min: batteryVoltage,
                max: upperBatteryVoltage(for: ruuviTag),
                counter: nil,
                delay: nil,
                description: batteryVoltageDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(batteryVoltage: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(batteryVoltage: batteryVoltage, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .battery,
                settingType: .upperBound,
                isEnabled: isOn(type: .batteryVoltage(lower: 0, upper: 0), for: ruuviTag),
                min: lowerBatteryVoltage(for: ruuviTag),
                max: batteryVoltage,
                counter: nil,
                delay: nil,
                description: batteryVoltageDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setBatteryVoltage(description: String?, ruuviTag: RuuviTagSensor) {
        setBatteryVoltage(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .battery,
                settingType: .description,
                isEnabled: isOn(type: .batteryVoltage(lower: 0, upper: 0), for: ruuviTag),
                min: lowerBatteryVoltage(for: ruuviTag),
                max: upperBatteryVoltage(for: ruuviTag),
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - AQI
    func setLower(aqi: Double?, ruuviTag: RuuviTagSensor) {
        setLower(aqi: aqi, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .aqi,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .aqi(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: aqi ?? 0,
                max: upperAQI(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: aqiDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(aqi: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(aqi: aqi, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .aqi,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .aqi(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerAQI(for: ruuviTag) ?? 0,
                max: aqi ?? 0,
                counter: nil,
                delay: nil,
                description: aqiDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setAQI(description: String?, ruuviTag: RuuviTagSensor) {
        setAQI(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .aqi,
                settingType: .description,
                isEnabled: isOn(
                    type: .aqi(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerAQI(for: ruuviTag) ?? 0,
                max: upperAQI(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - CO2
    func setLower(carbonDioxide: Double?, ruuviTag: RuuviTagSensor) {
        setLower(carbonDioxide: carbonDioxide, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .co2,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .carbonDioxide(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: carbonDioxide ?? 0,
                max: upperCarbonDioxide(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: carbonDioxideDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(carbonDioxide: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(carbonDioxide: carbonDioxide, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .co2,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .carbonDioxide(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerCarbonDioxide(for: ruuviTag) ?? 0,
                max: carbonDioxide ?? 0,
                counter: nil,
                delay: nil,
                description: carbonDioxideDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setCarbonDioxide(description: String?, ruuviTag: RuuviTagSensor) {
        setCarbonDioxide(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .co2,
                settingType: .description,
                isEnabled: isOn(
                    type: .carbonDioxide(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerCarbonDioxide(for: ruuviTag) ?? 0,
                max: upperCarbonDioxide(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - PM1
    func setLower(pm1: Double?, ruuviTag: RuuviTagSensor) {
        setLower(pm1: pm1, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm10,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .pMatter1(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: pm1 ?? 0,
                max: upperPM1(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: pm1Description(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(pm1: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(pm1: pm1, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm10,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .pMatter1(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerPM1(for: ruuviTag) ?? 0,
                max: pm1 ?? 0,
                counter: nil,
                delay: nil,
                description: pm1Description(for: ruuviTag),
                for: macId
            )
        }
    }

    func setPM1(description: String?, ruuviTag: RuuviTagSensor) {
        setPM1(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm10,
                settingType: .description,
                isEnabled: isOn(
                    type: .pMatter1(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerPM1(for: ruuviTag) ?? 0,
                max: upperPM1(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - PM2.5
    func setLower(pm25: Double?, ruuviTag: RuuviTagSensor) {
        setLower(pm25: pm25, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm25,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .pMatter25(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: pm25 ?? 0,
                max: upperPM25(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: pm25Description(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(pm25: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(pm25: pm25, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm25,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .pMatter25(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerPM25(for: ruuviTag) ?? 0,
                max: pm25 ?? 0,
                counter: nil,
                delay: nil,
                description: pm25Description(for: ruuviTag),
                for: macId
            )
        }
    }

    func setPM25(description: String?, ruuviTag: RuuviTagSensor) {
        setPM25(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm25,
                settingType: .description,
                isEnabled: isOn(
                    type: .pMatter25(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerPM25(for: ruuviTag) ?? 0,
                max: upperPM25(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - PM4
    func setLower(pm4: Double?, ruuviTag: RuuviTagSensor) {
        setLower(pm4: pm4, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm40,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .pMatter4(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: pm4 ?? 0,
                max: upperPM4(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: pm4Description(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(pm4: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(pm4: pm4, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm40,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .pMatter4(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerPM4(for: ruuviTag) ?? 0,
                max: pm4 ?? 0,
                counter: nil,
                delay: nil,
                description: pm4Description(for: ruuviTag),
                for: macId
            )
        }
    }

    func setPM4(description: String?, ruuviTag: RuuviTagSensor) {
        setPM4(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm40,
                settingType: .description,
                isEnabled: isOn(
                    type: .pMatter4(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerPM4(for: ruuviTag) ?? 0,
                max: upperPM4(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - PM10
    func setLower(pm10: Double?, ruuviTag: RuuviTagSensor) {
        setLower(pm10: pm10, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm100,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .pMatter10(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: pm10 ?? 0,
                max: upperPM10(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: pm10Description(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(pm10: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(pm10: pm10, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm100,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .pMatter10(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerPM10(for: ruuviTag) ?? 0,
                max: pm10 ?? 0,
                counter: nil,
                delay: nil,
                description: pm10Description(for: ruuviTag),
                for: macId
            )
        }
    }

    func setPM10(description: String?, ruuviTag: RuuviTagSensor) {
        setPM10(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .pm100,
                settingType: .description,
                isEnabled: isOn(
                    type: .pMatter10(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerPM10(for: ruuviTag) ?? 0,
                max: upperPM10(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - VOC
    func setLower(voc: Double?, ruuviTag: RuuviTagSensor) {
        setLower(voc: voc, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .voc,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .voc(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: voc ?? 0,
                max: upperVOC(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: vocDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(voc: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(voc: voc, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .voc,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .voc(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerVOC(for: ruuviTag) ?? 0,
                max: voc ?? 0,
                counter: nil,
                delay: nil,
                description: vocDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setVOC(description: String?, ruuviTag: RuuviTagSensor) {
        setVOC(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .voc,
                settingType: .description,
                isEnabled: isOn(
                    type: .voc(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerVOC(for: ruuviTag) ?? 0,
                max: upperVOC(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - NOX
    func setLower(nox: Double?, ruuviTag: RuuviTagSensor) {
        setLower(nox: nox, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .nox,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .nox(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: nox ?? 0,
                max: upperNOX(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: noxDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(nox: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(nox: nox, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .nox,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .nox(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerNOX(for: ruuviTag) ?? 0,
                max: nox ?? 0,
                counter: nil,
                delay: nil,
                description: noxDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setNOX(description: String?, ruuviTag: RuuviTagSensor) {
        setNOX(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .nox,
                settingType: .description,
                isEnabled: isOn(
                    type: .nox(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerNOX(for: ruuviTag) ?? 0,
                max: upperNOX(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - Sound Instant
    func setLower(soundInstant: Double?, ruuviTag: RuuviTagSensor) {
        setLower(soundInstant: soundInstant, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .soundInstant,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .soundInstant(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: soundInstant ?? 0,
                max: upperSoundInstant(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: soundInstantDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(soundInstant: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(soundInstant: soundInstant, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .soundInstant,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .soundInstant(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerSoundInstant(for: ruuviTag) ?? 0,
                max: soundInstant ?? 0,
                counter: nil,
                delay: nil,
                description: soundInstantDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setSoundInstant(description: String?, ruuviTag: RuuviTagSensor) {
        setSoundInstant(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .soundInstant,
                settingType: .description,
                isEnabled: isOn(
                    type: .soundInstant(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerSoundInstant(for: ruuviTag) ?? 0,
                max: upperSoundInstant(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - Sound Average
    func setLower(soundAverage: Double?, ruuviTag: RuuviTagSensor) {
        setLower(soundAverage: soundAverage, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .soundAverage,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .soundAverage(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: soundAverage ?? 0,
                max: upperSoundAverage(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: soundAverageDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(soundAverage: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(soundAverage: soundAverage, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .soundAverage,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .soundAverage(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerSoundAverage(for: ruuviTag) ?? 0,
                max: soundAverage ?? 0,
                counter: nil,
                delay: nil,
                description: soundAverageDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setSoundAverage(description: String?, ruuviTag: RuuviTagSensor) {
        setSoundAverage(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .soundAverage,
                settingType: .description,
                isEnabled: isOn(
                    type: .soundAverage(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerSoundAverage(for: ruuviTag) ?? 0,
                max: upperSoundAverage(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - Sound Peak
    func setLower(soundPeak: Double?, ruuviTag: RuuviTagSensor) {
        setLower(soundPeak: soundPeak, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .soundPeak,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .soundPeak(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: soundPeak ?? 0,
                max: upperSoundPeak(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: soundPeakDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(soundPeak: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(soundPeak: soundPeak, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .soundPeak,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .soundPeak(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerSoundPeak(for: ruuviTag) ?? 0,
                max: soundPeak ?? 0,
                counter: nil,
                delay: nil,
                description: soundPeakDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setSoundPeak(description: String?, ruuviTag: RuuviTagSensor) {
        setSoundPeak(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .soundPeak,
                settingType: .description,
                isEnabled: isOn(
                    type: .soundPeak(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerSoundPeak(for: ruuviTag) ?? 0,
                max: upperSoundPeak(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - Luminosity
    func setLower(luminosity: Double?, ruuviTag: RuuviTagSensor) {
        setLower(luminosity: luminosity, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .luminosity,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .luminosity(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: luminosity ?? 0,
                max: upperLuminosity(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: luminosityDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(luminosity: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(luminosity: luminosity, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .luminosity,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .luminosity(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerLuminosity(for: ruuviTag) ?? 0,
                max: luminosity ?? 0,
                counter: nil,
                delay: nil,
                description: luminosityDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setLuminosity(description: String?, ruuviTag: RuuviTagSensor) {
        setLuminosity(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .luminosity,
                settingType: .description,
                isEnabled: isOn(
                    type: .luminosity(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerLuminosity(for: ruuviTag) ?? 0,
                max: upperLuminosity(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
        }
    }

    // MARK: - Movement
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

    // MARK: - Cloud Connection
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
    private let cloud: RuuviCloudAlertBridge
    private let alertPersistence: AlertPersistence
    private let localIDs: RuuviLocalIDs
    private var ruuviLocalSettings: RuuviLocalSettings

    public init(
        cloud: RuuviCloud,
        localIDs: RuuviLocalIDs,
        ruuviLocalSettings: RuuviLocalSettings
    ) {
        self.cloud = RuuviCloudAlertBridge(cloud: cloud)
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
                guard let cloudAlertType = cloudAlert.type else { return }
                var type: AlertType?
                var applyCloudMetadata: (() -> Void)?
                switch cloudAlertType {
                case .temperature:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .temperature(lower: min, upper: max)
                    applyCloudMetadata = { [weak self] in
                        guard let self else { return }
                        // This sets the increased limit for external sensor when synced to cloud data.
                        let temperatureUnit = self.ruuviLocalSettings.temperatureUnit
                        let standardMinmimumBound = temperatureUnit.alertRange.lowerBound
                        let standardMaximumBound = temperatureUnit.alertRange.upperBound
                        if min < standardMinmimumBound || max > standardMaximumBound {
                            self.ruuviLocalSettings.setShowCustomTempAlertBound(true, for: physicalSensor.id)
                        }
                        self.setTemperature(description: cloudAlert.description, for: physicalSensor)
                    }
                case .humidity:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    // in percent on cloud, in fraction locally
                    type = .relativeHumidity(
                        lower: min / 100.0,
                        upper: max / 100.0
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setRelativeHumidity(description: cloudAlert.description, for: physicalSensor)
                    }
                case .humidityAbsolute:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .humidity(
                        lower: Humidity(value: min, unit: .absolute),
                        upper: Humidity(value: max, unit: .absolute)
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setHumidity(description: cloudAlert.description, for: physicalSensor)
                    }
                case .dewPoint:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .dewPoint(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setDewPoint(description: cloudAlert.description, for: physicalSensor)
                    }
                case .pressure:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    // in Pa on cloud, in hPa locally
                    type = .pressure(
                        lower: min / 100.0,
                        upper: max / 100.0
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setPressure(description: cloudAlert.description, for: physicalSensor)
                    }
                case .movement:
                    guard let counter = cloudAlert.counter else { return }
                    type = .movement(last: counter)
                    applyCloudMetadata = { [weak self] in
                        self?.setMovement(description: cloudAlert.description, for: physicalSensor)
                    }
                case .signal:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .signal(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setSignal(description: cloudAlert.description, for: physicalSensor)
                    }
                case .aqi:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .aqi(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setAQI(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .co2:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .carbonDioxide(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setCarbonDioxide(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .pm10:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .pMatter1(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setPM1(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .pm25:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .pMatter25(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setPM25(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .pm40:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .pMatter4(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setPM4(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .pm100:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .pMatter10(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setPM10(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .voc:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .voc(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setVOC(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .nox:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .nox(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setNOX(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .soundInstant:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .soundInstant(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setSoundInstant(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .soundAverage:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .soundAverage(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setSoundAverage(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .soundPeak:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .soundPeak(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setSoundPeak(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .luminosity:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .luminosity(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setLuminosity(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .battery:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .batteryVoltage(
                        lower: min,
                        upper: max
                    )
                    applyCloudMetadata = { [weak self] in
                        self?.setBatteryVoltage(
                            description: cloudAlert.description,
                            for: physicalSensor
                        )
                    }
                case .offline:
                    guard let unseenDuration = cloudAlert.max else { return }
                    type = .cloudConnection(unseenDuration: unseenDuration)
                    applyCloudMetadata = { [weak self] in
                        self?.setCloudConnection(description: cloudAlert.description, for: physicalSensor)
                    }
                }

                guard let type else { return }

                let localUpdatedAt = alertUpdatedAt(for: physicalSensor, type: type)
                let cloudUpdatedAt = cloudAlert.lastUpdated

                let syncAction: SyncAction
                if cloudUpdatedAt == nil {
                    // API doesn't provide lastUpdated for alerts yet
                    // Fall back to cloud-authoritative behavior for backward compatibility
                    syncAction = .updateLocal
                } else {
                    syncAction = SyncCollisionResolver.resolve(
                        localTimestamp: localUpdatedAt,
                        cloudTimestamp: cloudUpdatedAt
                    )
                }

                switch syncAction {
                case .updateLocal:
                    applyCloudMetadata?()
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
                    setAlertUpdatedAt(cloudUpdatedAt, type: type, for: physicalSensor)

                case .keepLocalAndQueue:
                    queueAlertStateToCloud(
                        type: type,
                        cloudType: cloudAlertType,
                        for: physicalSensor,
                        macId: macId
                    )

                case .noAction:
                    break
                }
            }
        }
    }

    private func alertUpdatedAt(for sensor: PhysicalSensor, type: AlertType) -> Date? {
        var dates = [Date]()
        if let luid = sensor.luid?.value,
           let date = alertPersistence.updatedAt(for: luid, of: type) {
            dates.append(date)
        }
        if let macId = sensor.macId?.value,
           let date = alertPersistence.updatedAt(for: macId, of: type) {
            dates.append(date)
        }
        return dates.max()
    }

    private func setAlertUpdatedAt(_ date: Date?, type: AlertType, for sensor: PhysicalSensor) {
        if let luid = sensor.luid?.value {
            alertPersistence.setUpdatedAt(date, for: luid, of: type)
        }
        if let macId = sensor.macId?.value {
            alertPersistence.setUpdatedAt(date, for: macId, of: type)
        }
    }

    private func touchAlertUpdatedAt(type: AlertType, for sensor: PhysicalSensor) {
        setAlertUpdatedAt(Date(), type: type, for: sensor)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func queueAlertStateToCloud(
        type: AlertType,
        cloudType: RuuviCloudAlertType,
        for sensor: PhysicalSensor,
        macId: MACIdentifier
    ) {
        let isEnabled = isOn(type: type, for: sensor)

        switch cloudType {
        case .temperature:
            cloud.setAlert(
                type: .temperature,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerCelsius(for: sensor),
                max: upperCelsius(for: sensor),
                counter: nil,
                delay: nil,
                description: temperatureDescription(for: sensor),
                for: macId
            )
        case .humidity:
            cloud.setAlert(
                type: .humidity,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerRelativeHumidity(for: sensor).map { $0 * 100.0 },
                max: upperRelativeHumidity(for: sensor).map { $0 * 100.0 },
                counter: nil,
                delay: nil,
                description: relativeHumidityDescription(for: sensor),
                for: macId
            )
        case .humidityAbsolute:
            cloud.setAlert(
                type: .humidityAbsolute,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerHumidity(for: sensor)?.converted(to: .absolute).value,
                max: upperHumidity(for: sensor)?.converted(to: .absolute).value,
                counter: nil,
                delay: nil,
                description: humidityDescription(for: sensor),
                for: macId
            )
        case .dewPoint:
            cloud.setAlert(
                type: .dewPoint,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerDewPoint(for: sensor),
                max: upperDewPoint(for: sensor),
                counter: nil,
                delay: nil,
                description: dewPointDescription(for: sensor),
                for: macId
            )
        case .pressure:
            cloud.setAlert(
                type: .pressure,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerPressure(for: sensor).map { $0 * 100.0 },
                max: upperPressure(for: sensor).map { $0 * 100.0 },
                counter: nil,
                delay: nil,
                description: pressureDescription(for: sensor),
                for: macId
            )
        case .signal:
            cloud.setAlert(
                type: .signal,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerSignal(for: sensor),
                max: upperSignal(for: sensor),
                counter: nil,
                delay: nil,
                description: signalDescription(for: sensor),
                for: macId
            )
        case .battery:
            cloud.setAlert(
                type: .battery,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerBatteryVoltage(for: sensor),
                max: upperBatteryVoltage(for: sensor),
                counter: nil,
                delay: nil,
                description: batteryVoltageDescription(for: sensor),
                for: macId
            )
        case .aqi:
            cloud.setAlert(
                type: .aqi,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerAQI(for: sensor),
                max: upperAQI(for: sensor),
                counter: nil,
                delay: nil,
                description: aqiDescription(for: sensor),
                for: macId
            )
        case .co2:
            cloud.setAlert(
                type: .co2,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerCarbonDioxide(for: sensor),
                max: upperCarbonDioxide(for: sensor),
                counter: nil,
                delay: nil,
                description: carbonDioxideDescription(for: sensor),
                for: macId
            )
        case .pm10:
            cloud.setAlert(
                type: .pm10,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerPM1(for: sensor),
                max: upperPM1(for: sensor),
                counter: nil,
                delay: nil,
                description: pm1Description(for: sensor),
                for: macId
            )
        case .pm25:
            cloud.setAlert(
                type: .pm25,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerPM25(for: sensor),
                max: upperPM25(for: sensor),
                counter: nil,
                delay: nil,
                description: pm25Description(for: sensor),
                for: macId
            )
        case .pm40:
            cloud.setAlert(
                type: .pm40,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerPM4(for: sensor),
                max: upperPM4(for: sensor),
                counter: nil,
                delay: nil,
                description: pm4Description(for: sensor),
                for: macId
            )
        case .pm100:
            cloud.setAlert(
                type: .pm100,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerPM10(for: sensor),
                max: upperPM10(for: sensor),
                counter: nil,
                delay: nil,
                description: pm10Description(for: sensor),
                for: macId
            )
        case .voc:
            cloud.setAlert(
                type: .voc,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerVOC(for: sensor),
                max: upperVOC(for: sensor),
                counter: nil,
                delay: nil,
                description: vocDescription(for: sensor),
                for: macId
            )
        case .nox:
            cloud.setAlert(
                type: .nox,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerNOX(for: sensor),
                max: upperNOX(for: sensor),
                counter: nil,
                delay: nil,
                description: noxDescription(for: sensor),
                for: macId
            )
        case .soundInstant:
            cloud.setAlert(
                type: .soundInstant,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerSoundInstant(for: sensor),
                max: upperSoundInstant(for: sensor),
                counter: nil,
                delay: nil,
                description: soundInstantDescription(for: sensor),
                for: macId
            )
        case .soundAverage:
            cloud.setAlert(
                type: .soundAverage,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerSoundAverage(for: sensor),
                max: upperSoundAverage(for: sensor),
                counter: nil,
                delay: nil,
                description: soundAverageDescription(for: sensor),
                for: macId
            )
        case .soundPeak:
            cloud.setAlert(
                type: .soundPeak,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerSoundPeak(for: sensor),
                max: upperSoundPeak(for: sensor),
                counter: nil,
                delay: nil,
                description: soundPeakDescription(for: sensor),
                for: macId
            )
        case .luminosity:
            cloud.setAlert(
                type: .luminosity,
                settingType: .state,
                isEnabled: isEnabled,
                min: lowerLuminosity(for: sensor),
                max: upperLuminosity(for: sensor),
                counter: nil,
                delay: nil,
                description: luminosityDescription(for: sensor),
                for: macId
            )
        case .offline:
            cloud.setAlert(
                type: .offline,
                settingType: .state,
                isEnabled: isEnabled,
                min: 0,
                max: cloudConnectionUnseenDuration(for: sensor),
                counter: nil,
                delay: 0,
                description: cloudConnectionDescription(for: sensor),
                for: macId
            )
        case .movement:
            cloud.setAlert(
                type: .movement,
                settingType: .state,
                isEnabled: isEnabled,
                min: nil,
                max: nil,
                counter: movementCounter(for: sensor),
                delay: nil,
                description: movementDescription(for: sensor),
                for: macId
            )
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
        alertIdentifierValue(for: sensor) {
            alertPersistence.alert(for: $0, of: type)
        }
    }

    func register(type: AlertType, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.register(type: type, for: $0)
        }
        touchAlertUpdatedAt(type: type, for: sensor)
        postAlertDidChange(with: sensor, of: type)
    }

    func unregister(type: AlertType, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.unregister(type: type, for: $0)
        }
        touchAlertUpdatedAt(type: type, for: sensor)
        postAlertDidChange(with: sensor, of: type)
    }

    public func remove(type: AlertType, ruuviTag: RuuviTagSensor) {
        updateAlertIdentifiers(for: ruuviTag) {
            alertPersistence.remove(type: type, for: $0)
        }
        touchAlertUpdatedAt(type: type, for: ruuviTag)
    }

    public func mute(type: AlertType, for sensor: PhysicalSensor, till date: Date) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.mute(type: type, for: $0, till: date)
        }
        postAlertDidChange(with: sensor, of: type)
    }

    public func unmute(type: AlertType, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.unmute(type: type, for: $0)
        }
        postAlertDidChange(with: sensor, of: type)
    }

    public func mutedTill(type: AlertType, for sensor: PhysicalSensor) -> Date? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.mutedTill(type: type, for: $0)
        }
    }

    public func trigger(
        type: AlertType,
        trigerred: Bool?,
        trigerredAt: String?,
        for sensor: PhysicalSensor
    ) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.trigger(
                type: type,
                trigerred: trigerred,
                trigerredAt: trigerredAt,
                for: $0
            )
        }
        postAlertTriggerDidChange(with: sensor, of: type)
    }

    public func triggered(
        for sensor: PhysicalSensor,
        of type: AlertType
    ) -> Bool? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.triggered(for: $0, of: type)
        }
    }

    public func triggeredAt(
        for sensor: PhysicalSensor,
        of type: AlertType
    ) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.triggeredAt(for: $0, of: type)
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
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerCelsius(for: $0)
        }
    }

    func upperCelsius(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperCelsius(for: $0)
        }
    }

    func temperatureDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.temperatureDescription(for: $0)
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

    // Private helpers
    private func setLower(celsius: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(celsius: celsius, for: $0)
        }

        touchAlertUpdatedAt(type: .temperature(lower: 0, upper: 0), for: sensor)
        if let l = celsius, let u = upperCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }

    private func setUpper(celsius: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(celsius: celsius, for: $0)
        }

        touchAlertUpdatedAt(type: .temperature(lower: 0, upper: 0), for: sensor)
        if let u = celsius, let l = lowerCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }

    private func setTemperature(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setTemperature(description: description, for: $0)
        }

        touchAlertUpdatedAt(type: .temperature(lower: 0, upper: 0), for: sensor)
        if let l = lowerCelsius(for: sensor), let u = upperCelsius(for: sensor) {
            postAlertDidChange(with: sensor, of: .temperature(lower: l, upper: u))
        }
    }
}

// MARK: - Relative Humidity

public extension RuuviServiceAlertImpl {
    func lowerRelativeHumidity(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerRelativeHumidity(for: $0)
        }
    }

    func upperRelativeHumidity(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperRelativeHumidity(for: $0)
        }
    }

    func relativeHumidityDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.relativeHumidityDescription(for: $0)
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

    // Private helpers
    private func setLower(relativeHumidity: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(relativeHumidity: relativeHumidity, for: $0)
        }
        touchAlertUpdatedAt(type: .relativeHumidity(lower: 0, upper: 0), for: sensor)
        if let l = relativeHumidity, let u = upperRelativeHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .relativeHumidity(lower: l, upper: u))
        }
    }

    private func setUpper(relativeHumidity: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(relativeHumidity: relativeHumidity, for: $0)
        }
        touchAlertUpdatedAt(type: .relativeHumidity(lower: 0, upper: 0), for: sensor)
        if let u = relativeHumidity, let l = lowerRelativeHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .relativeHumidity(lower: l, upper: u))
        }
    }

    private func setRelativeHumidity(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setRelativeHumidity(description: description, for: $0)
        }

        touchAlertUpdatedAt(type: .relativeHumidity(lower: 0, upper: 0), for: sensor)
        if let l = lowerRelativeHumidity(for: sensor), let u = upperRelativeHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .relativeHumidity(lower: l, upper: u))
        }
    }
}

// MARK: - Humidity

public extension RuuviServiceAlertImpl {
    func lowerHumidity(for sensor: PhysicalSensor) -> Humidity? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerHumidity(for: $0)
        }
    }

    func setLower(humidity: Humidity?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(humidity: humidity, for: $0)
        }
        touchAlertUpdatedAt(type: .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute), for: sensor)
        if let ruuviTag = sensor as? RuuviTagSensor,
           ruuviTag.isCloud,
           let macId = ruuviTag.macId {
            let lowerValue = humidity?.converted(to: .absolute).value
            let upperValue = upperHumidity(for: sensor)?.converted(to: .absolute).value
            cloud.setAlert(
                type: .humidityAbsolute,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute),
                    for: ruuviTag
                ),
                min: lowerValue ?? 0,
                max: upperValue ?? 0,
                counter: nil,
                delay: nil,
                description: humidityDescription(for: sensor),
                for: macId
            )
        }
        if let l = humidity, let u = upperHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .humidity(lower: l, upper: u))
        }
    }

    func upperHumidity(for sensor: PhysicalSensor) -> Humidity? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperHumidity(for: $0)
        }
    }

    func setUpper(humidity: Humidity?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(humidity: humidity, for: $0)
        }
        touchAlertUpdatedAt(type: .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute), for: sensor)
        if let ruuviTag = sensor as? RuuviTagSensor,
           ruuviTag.isCloud,
           let macId = ruuviTag.macId {
            let lowerValue = lowerHumidity(for: sensor)?.converted(to: .absolute).value
            let upperValue = humidity?.converted(to: .absolute).value
            cloud.setAlert(
                type: .humidityAbsolute,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute),
                    for: ruuviTag
                ),
                min: lowerValue ?? 0,
                max: upperValue ?? 0,
                counter: nil,
                delay: nil,
                description: humidityDescription(for: sensor),
                for: macId
            )
        }
        if let u = humidity, let l = lowerHumidity(for: sensor) {
            postAlertDidChange(with: sensor, of: .humidity(lower: l, upper: u))
        }
    }

    func humidityDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.humidityDescription(for: $0)
        }
    }

    func setHumidity(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setHumidity(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute), for: sensor)
        if let ruuviTag = sensor as? RuuviTagSensor,
           ruuviTag.isCloud,
           let macId = ruuviTag.macId {
            let lowerValue = lowerHumidity(for: sensor)?.converted(to: .absolute).value
            let upperValue = upperHumidity(for: sensor)?.converted(to: .absolute).value
            cloud.setAlert(
                type: .humidityAbsolute,
                settingType: .description,
                isEnabled: isOn(
                    type: .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute),
                    for: ruuviTag
                ),
                min: lowerValue ?? 0,
                max: upperValue ?? 0,
                counter: nil,
                delay: nil,
                description: description,
                for: macId
            )
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

// MARK: - Dew Point

public extension RuuviServiceAlertImpl {
    func lowerDewPoint(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerDewPoint(for: $0)
        }
    }

    func upperDewPoint(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperDewPoint(for: $0)
        }
    }

    func dewPointDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.dewPointDescription(for: $0)
        }
    }

    func lowerDewPoint(for uuid: String) -> Double? {
        alertPersistence.lowerDewPoint(for: uuid)
    }

    func upperDewPoint(for uuid: String) -> Double? {
        alertPersistence.upperDewPoint(for: uuid)
    }

    func dewPointDescription(for uuid: String) -> String? {
        alertPersistence.dewPointDescription(for: uuid)
    }

    // Private helpers
    private func setLower(dewPoint: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(dewPoint: dewPoint, for: $0)
        }
        touchAlertUpdatedAt(type: .dewPoint(lower: 0, upper: 0), for: sensor)
        if let l = dewPoint, let u = upperDewPoint(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }

    private func setUpper(dewPoint: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(dewPoint: dewPoint, for: $0)
        }
        touchAlertUpdatedAt(type: .dewPoint(lower: 0, upper: 0), for: sensor)
        if let u = dewPoint, let l = lowerDewPoint(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }

    private func setDewPoint(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setDewPoint(description: description, for: $0)
        }

        touchAlertUpdatedAt(type: .dewPoint(lower: 0, upper: 0), for: sensor)
        if let l = lowerDewPoint(for: sensor),
           let u = upperDewPoint(for: sensor) {
            postAlertDidChange(with: sensor, of: .dewPoint(lower: l, upper: u))
        }
    }
}

// MARK: - Pressure

public extension RuuviServiceAlertImpl {
    func lowerPressure(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerPressure(for: $0)
        }
    }

    func upperPressure(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperPressure(for: $0)
        }
    }

    func pressureDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.pressureDescription(for: $0)
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

    // Private helpers
    private func setLower(pressure: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(pressure: pressure, for: $0)
        }

        touchAlertUpdatedAt(type: .pressure(lower: 0, upper: 0), for: sensor)
        if let l = pressure, let u = upperPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }

    private func setUpper(pressure: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(pressure: pressure, for: $0)
        }

        touchAlertUpdatedAt(type: .pressure(lower: 0, upper: 0), for: sensor)
        if let u = pressure, let l = lowerPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }

    private func setPressure(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setPressure(description: description, for: $0)
        }

        touchAlertUpdatedAt(type: .pressure(lower: 0, upper: 0), for: sensor)
        if let l = lowerPressure(for: sensor), let u = upperPressure(for: sensor) {
            postAlertDidChange(with: sensor, of: .pressure(lower: l, upper: u))
        }
    }
}

// MARK: - Signal

public extension RuuviServiceAlertImpl {
    func lowerSignal(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerSignal(for: $0)
        }
    }

    func upperSignal(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperSignal(for: $0)
        }
    }

    func signalDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.signalDescription(for: $0)
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

    // Private helpers
    private func setLower(signal: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(signal: signal, for: $0)
        }

        touchAlertUpdatedAt(type: .signal(lower: 0, upper: 0), for: sensor)
        if let l = signal, let u = upperSignal(for: sensor) {
            postAlertDidChange(with: sensor, of: .signal(lower: l, upper: u))
        }
    }

    private func setUpper(signal: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(signal: signal, for: $0)
        }

        touchAlertUpdatedAt(type: .signal(lower: 0, upper: 0), for: sensor)
        if let u = signal, let l = lowerSignal(for: sensor) {
            postAlertDidChange(with: sensor, of: .signal(lower: l, upper: u))
        }
    }

    private func setSignal(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setSignal(description: description, for: $0)
        }

        touchAlertUpdatedAt(type: .signal(lower: 0, upper: 0), for: sensor)
        if let l = lowerSignal(for: sensor), let u = upperSignal(for: sensor) {
            postAlertDidChange(with: sensor, of: .signal(lower: l, upper: u))
        }
    }
}

// MARK: - Battery Voltage

public extension RuuviServiceAlertImpl {
    func lowerBatteryVoltage(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerBatteryVoltage(for: $0)
        }
    }

    func upperBatteryVoltage(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperBatteryVoltage(for: $0)
        }
    }

    func batteryVoltageDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.batteryVoltageDescription(for: $0)
        }
    }

    func lowerBatteryVoltage(for uuid: String) -> Double? {
        alertPersistence.lowerBatteryVoltage(for: uuid)
    }

    func upperBatteryVoltage(for uuid: String) -> Double? {
        alertPersistence.upperBatteryVoltage(for: uuid)
    }

    func batteryVoltageDescription(for uuid: String) -> String? {
        alertPersistence.batteryVoltageDescription(for: uuid)
    }

    // Private helpers
    private func setLower(batteryVoltage: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(batteryVoltage: batteryVoltage, for: $0)
        }

        touchAlertUpdatedAt(type: .batteryVoltage(lower: 0, upper: 0), for: sensor)
        if let l = batteryVoltage, let u = upperBatteryVoltage(for: sensor) {
            postAlertDidChange(with: sensor, of: .batteryVoltage(lower: l, upper: u))
        }
    }

    private func setUpper(batteryVoltage: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(batteryVoltage: batteryVoltage, for: $0)
        }

        touchAlertUpdatedAt(type: .batteryVoltage(lower: 0, upper: 0), for: sensor)
        if let u = batteryVoltage, let l = lowerBatteryVoltage(for: sensor) {
            postAlertDidChange(with: sensor, of: .batteryVoltage(lower: l, upper: u))
        }
    }

    private func setBatteryVoltage(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setBatteryVoltage(description: description, for: $0)
        }

        touchAlertUpdatedAt(type: .batteryVoltage(lower: 0, upper: 0), for: sensor)
        if let l = lowerBatteryVoltage(for: sensor),
           let u = upperBatteryVoltage(for: sensor) {
            postAlertDidChange(with: sensor, of: .batteryVoltage(lower: l, upper: u))
        }
    }
}

// MARK: - AQI
public extension RuuviServiceAlertImpl {

    func lowerAQI(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerAQI(for: $0)
        }
    }

    func upperAQI(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperAQI(for: $0)
        }
    }

    func aqiDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.aqiDescription(for: $0)
        }
    }

    func lowerAQI(for uuid: String) -> Double? {
        alertPersistence.lowerAQI(for: uuid)
    }

    func upperAQI(for uuid: String) -> Double? {
        alertPersistence.upperAQI(for: uuid)
    }

    func aqiDescription(for uuid: String) -> String? {
        alertPersistence.aqiDescription(for: uuid)
    }

    // Private helpers
    private func setLower(aqi: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(aqi: aqi, for: $0)
        }
        touchAlertUpdatedAt(type: .aqi(lower: 0, upper: 0), for: sensor)
    }

    private func setUpper(aqi: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(aqi: aqi, for: $0)
        }
        touchAlertUpdatedAt(type: .aqi(lower: 0, upper: 0), for: sensor)
    }

    private func setAQI(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setAQI(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .aqi(lower: 0, upper: 0), for: sensor)
    }
}

// MARK: - Carbon Dioxide

public extension RuuviServiceAlertImpl {

    func lowerCarbonDioxide(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerCarbonDioxide(for: $0)
        }
    }

    func upperCarbonDioxide(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperCarbonDioxide(for: $0)
        }
    }

    func carbonDioxideDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.carbonDioxideDescription(for: $0)
        }
    }

    func lowerCarbonDioxide(for uuid: String) -> Double? {
        alertPersistence.lowerCarbonDioxide(for: uuid)
    }

    func upperCarbonDioxide(for uuid: String) -> Double? {
        alertPersistence.upperCarbonDioxide(for: uuid)
    }

    func carbonDioxideDescription(for uuid: String) -> String? {
        alertPersistence.carbonDioxideDescription(for: uuid)
    }

    // Private Helpers
    private func setLower(carbonDioxide: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(carbonDioxide: carbonDioxide, for: $0)
        }

        touchAlertUpdatedAt(type: .carbonDioxide(lower: 0, upper: 0), for: sensor)
        if let l = carbonDioxide, let u = upperCarbonDioxide(for: sensor) {
            postAlertDidChange(
                with: sensor,
                of: .carbonDioxide(lower: l, upper: u)
            )
        }
    }

    private func setUpper(carbonDioxide: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(carbonDioxide: carbonDioxide, for: $0)
        }

        touchAlertUpdatedAt(type: .carbonDioxide(lower: 0, upper: 0), for: sensor)
        if let l = lowerCarbonDioxide(for: sensor), let u = carbonDioxide {
            postAlertDidChange(
                with: sensor,
                of: .carbonDioxide(lower: l, upper: u)
            )
        }
    }

    private func setCarbonDioxide(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setCarbonDioxide(description: description, for: $0)
        }

        touchAlertUpdatedAt(type: .carbonDioxide(lower: 0, upper: 0), for: sensor)
        if let l = lowerCarbonDioxide(for: sensor), let u = upperCarbonDioxide(for: sensor) {
            postAlertDidChange(
                with: sensor,
                of: .carbonDioxide(lower: l, upper: u)
            )
        }
    }
}

// MARK: - PM1
public extension RuuviServiceAlertImpl {
    func lowerPM1(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerPM1(for: $0)
        }
    }

    func upperPM1(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperPM1(for: $0)
        }
    }

    func pm1Description(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.pm1Description(for: $0)
        }
    }

    func lowerPM1(for uuid: String) -> Double? {
        alertPersistence.lowerPM1(for: uuid)
    }

    func upperPM1(for uuid: String) -> Double? {
        alertPersistence.upperPM1(for: uuid)
    }

    func pm1Description(for uuid: String) -> String? {
        alertPersistence.pm1Description(for: uuid)
    }

    // Private helpers
    private func setLower(pm1: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(pm1: pm1, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter1(lower: 0, upper: 0), for: sensor)
    }

    private func setUpper(pm1: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(pm1: pm1, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter1(lower: 0, upper: 0), for: sensor)
    }

    private func setPM1(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setPM1(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter1(lower: 0, upper: 0), for: sensor)
    }
}

// MARK: - PM2.5
public extension RuuviServiceAlertImpl {
    func lowerPM25(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerPM25(for: $0)
        }
    }

    func upperPM25(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperPM25(for: $0)
        }
    }

    func pm25Description(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.pm25Description(for: $0)
        }
    }

    func lowerPM25(for uuid: String) -> Double? {
        alertPersistence.lowerPM25(for: uuid)
    }

    func upperPM25(for uuid: String) -> Double? {
        alertPersistence.upperPM25(for: uuid)
    }

    func pm25Description(for uuid: String) -> String? {
        alertPersistence.pm25Description(for: uuid)
    }

    // Private helpers
    private func setLower(pm25: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(pm25: pm25, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter25(lower: 0, upper: 0), for: sensor)
    }

    private func setUpper(pm25: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(pm25: pm25, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter25(lower: 0, upper: 0), for: sensor)
    }

    private func setPM25(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setPM25(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter25(lower: 0, upper: 0), for: sensor)
    }
}

// MARK: - PM4
public extension RuuviServiceAlertImpl {
    func lowerPM4(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerPM4(for: $0)
        }
    }

    func upperPM4(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperPM4(for: $0)
        }
    }

    func pm4Description(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.pm4Description(for: $0)
        }
    }

    func lowerPM4(for uuid: String) -> Double? {
        alertPersistence.lowerPM4(for: uuid)
    }

    func upperPM4(for uuid: String) -> Double? {
        alertPersistence.upperPM4(for: uuid)
    }

    func pm4Description(for uuid: String) -> String? {
        alertPersistence.pm4Description(for: uuid)
    }

    // Private helpers
    private func setLower(pm4: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(pm4: pm4, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter4(lower: 0, upper: 0), for: sensor)
    }

    private func setUpper(pm4: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(pm4: pm4, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter4(lower: 0, upper: 0), for: sensor)
    }

    private func setPM4(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setPM4(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter4(lower: 0, upper: 0), for: sensor)
    }
}

// MARK: - PM10
public extension RuuviServiceAlertImpl {
    func lowerPM10(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerPM10(for: $0)
        }
    }

    func upperPM10(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperPM10(for: $0)
        }
    }

    func pm10Description(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.pm10Description(for: $0)
        }
    }

    func lowerPM10(for uuid: String) -> Double? {
        alertPersistence.lowerPM10(for: uuid)
    }

    func upperPM10(for uuid: String) -> Double? {
        alertPersistence.upperPM10(for: uuid)
    }

    func pm10Description(for uuid: String) -> String? {
        alertPersistence.pm10Description(for: uuid)
    }

    // Private helpers
    private func setLower(pm10: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(pm10: pm10, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter10(lower: 0, upper: 0), for: sensor)
    }

    private func setUpper(pm10: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(pm10: pm10, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter10(lower: 0, upper: 0), for: sensor)
    }

    private func setPM10(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setPM10(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .pMatter10(lower: 0, upper: 0), for: sensor)
    }
}

// MARK: - VOC
public extension RuuviServiceAlertImpl {
    func lowerVOC(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerVOC(for: $0)
        }
    }

    func upperVOC(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperVOC(for: $0)
        }
    }

    func vocDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.vocDescription(for: $0)
        }
    }

    func lowerVOC(for uuid: String) -> Double? {
        alertPersistence.lowerVOC(for: uuid)
    }

    func upperVOC(for uuid: String) -> Double? {
        alertPersistence.upperVOC(for: uuid)
    }

    func vocDescription(for uuid: String) -> String? {
        alertPersistence.vocDescription(for: uuid)
    }

    // Private helpers
    private func setLower(voc: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(voc: voc, for: $0)
        }
        touchAlertUpdatedAt(type: .voc(lower: 0, upper: 0), for: sensor)
    }

    private func setUpper(voc: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(voc: voc, for: $0)
        }
        touchAlertUpdatedAt(type: .voc(lower: 0, upper: 0), for: sensor)
    }

    private func setVOC(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setVOC(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .voc(lower: 0, upper: 0), for: sensor)
    }
}

// MARK: - NOX
public extension RuuviServiceAlertImpl {

    func lowerNOX(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerNOX(for: $0)
        }
    }

    func upperNOX(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperNOX(for: $0)
        }
    }

    func noxDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.noxDescription(for: $0)
        }
    }

    func lowerNOX(for uuid: String) -> Double? {
        alertPersistence.lowerNOX(for: uuid)
    }

    func upperNOX(for uuid: String) -> Double? {
        alertPersistence.upperNOX(for: uuid)
    }

    func noxDescription(for uuid: String) -> String? {
        alertPersistence.noxDescription(for: uuid)
    }

    // Private helpers
    private func setLower(nox: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(nox: nox, for: $0)
        }
        touchAlertUpdatedAt(type: .nox(lower: 0, upper: 0), for: sensor)
    }

    private func setUpper(nox: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(nox: nox, for: $0)
        }
        touchAlertUpdatedAt(type: .nox(lower: 0, upper: 0), for: sensor)
    }

    private func setNOX(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setNOX(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .nox(lower: 0, upper: 0), for: sensor)
    }
}

// MARK: - Sound Instant
public extension RuuviServiceAlertImpl {

    func lowerSoundInstant(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerSoundInstant(for: $0)
        }
    }

    func upperSoundInstant(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperSoundInstant(for: $0)
        }
    }

    func soundInstantDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.soundInstantDescription(for: $0)
        }
    }

    func lowerSoundInstant(for uuid: String) -> Double? {
        alertPersistence.lowerSoundInstant(for: uuid)
    }

    func upperSoundInstant(for uuid: String) -> Double? {
        alertPersistence.upperSoundInstant(for: uuid)
    }

    func soundInstantDescription(for uuid: String) -> String? {
        alertPersistence.soundInstantDescription(for: uuid)
    }

    // Private helpers
    private func setLower(soundInstant: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(soundInstant: soundInstant, for: $0)
        }
        touchAlertUpdatedAt(type: .soundInstant(lower: 0, upper: 0), for: sensor)
    }

    private func setUpper(soundInstant: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(soundInstant: soundInstant, for: $0)
        }
        touchAlertUpdatedAt(type: .soundInstant(lower: 0, upper: 0), for: sensor)
    }

    private func setSoundInstant(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setSoundInstant(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .soundInstant(lower: 0, upper: 0), for: sensor)
    }
}

// MARK: - Sound Average
public extension RuuviServiceAlertImpl {

    func lowerSoundAverage(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerSoundAverage(for: $0)
        }
    }

    func upperSoundAverage(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperSoundAverage(for: $0)
        }
    }

    func soundAverageDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.soundAverageDescription(for: $0)
        }
    }

    func lowerSoundAverage(for uuid: String) -> Double? {
        alertPersistence.lowerSoundAverage(for: uuid)
    }

    func upperSoundAverage(for uuid: String) -> Double? {
        alertPersistence.upperSoundAverage(for: uuid)
    }

    func soundAverageDescription(for uuid: String) -> String? {
        alertPersistence.soundAverageDescription(for: uuid)
    }

    // Private helpers
    private func setLower(soundAverage: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(soundAverage: soundAverage, for: $0)
        }
        touchAlertUpdatedAt(type: .soundAverage(lower: 0, upper: 0), for: sensor)
    }

    private func setUpper(soundAverage: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(soundAverage: soundAverage, for: $0)
        }
        touchAlertUpdatedAt(type: .soundAverage(lower: 0, upper: 0), for: sensor)
    }

    private func setSoundAverage(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setSoundAverage(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .soundAverage(lower: 0, upper: 0), for: sensor)
    }
}

// MARK: - Sound Peak
public extension RuuviServiceAlertImpl {

    func lowerSoundPeak(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerSoundPeak(for: $0)
        }
    }

    func upperSoundPeak(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperSoundPeak(for: $0)
        }
    }

    func soundPeakDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.soundPeakDescription(for: $0)
        }
    }

    func lowerSoundPeak(for uuid: String) -> Double? {
        alertPersistence.lowerSoundPeak(for: uuid)
    }

    func upperSoundPeak(for uuid: String) -> Double? {
        alertPersistence.upperSoundPeak(for: uuid)
    }

    func soundPeakDescription(for uuid: String) -> String? {
        alertPersistence.soundPeakDescription(for: uuid)
    }

    // Private helpers
    private func setLower(soundPeak: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(soundPeak: soundPeak, for: $0)
        }
        touchAlertUpdatedAt(type: .soundPeak(lower: 0, upper: 0), for: sensor)
    }

    private func setUpper(soundPeak: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(soundPeak: soundPeak, for: $0)
        }
        touchAlertUpdatedAt(type: .soundPeak(lower: 0, upper: 0), for: sensor)
    }

    private func setSoundPeak(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setSoundPeak(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .soundPeak(lower: 0, upper: 0), for: sensor)
    }
}

// MARK: - Luminosity
public extension RuuviServiceAlertImpl {
    func lowerLuminosity(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.lowerLuminosity(for: $0)
        }
    }

    func upperLuminosity(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.upperLuminosity(for: $0)
        }
    }

    func luminosityDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.luminosityDescription(for: $0)
        }
    }

    func lowerLuminosity(for uuid: String) -> Double? {
        alertPersistence.lowerLuminosity(for: uuid)
    }

    func upperLuminosity(for uuid: String) -> Double? {
        alertPersistence.upperLuminosity(for: uuid)
    }

    func luminosityDescription(for uuid: String) -> String? {
        alertPersistence.luminosityDescription(for: uuid)
    }

    // Private helpers
    private func setLower(luminosity: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLower(luminosity: luminosity, for: $0)
        }
        touchAlertUpdatedAt(type: .luminosity(lower: 0, upper: 0), for: sensor)
    }

    private func setUpper(luminosity: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setUpper(luminosity: luminosity, for: $0)
        }
        touchAlertUpdatedAt(type: .luminosity(lower: 0, upper: 0), for: sensor)
    }

    private func setLuminosity(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setLuminosity(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .luminosity(lower: 0, upper: 0), for: sensor)
    }
}

// MARK: - Connection

public extension RuuviServiceAlertImpl {
    func connectionDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.connectionDescription(for: $0)
        }
    }

    func setConnection(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setConnection(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .connection, for: sensor)
        postAlertDidChange(with: sensor, of: .connection)
    }

    func connectionDescription(for uuid: String) -> String? {
        alertPersistence.connectionDescription(for: uuid)
    }
}

// MARK: - Cloud Connection

public extension RuuviServiceAlertImpl {
    func cloudConnectionDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.cloudConnectionDescription(for: $0)
        }
    }

    func setCloudConnection(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setCloudConnection(description: description, for: $0)
        }
        touchAlertUpdatedAt(type: .cloudConnection(unseenDuration: 0), for: sensor)
    }

    func setCloudConnection(unseenDuration: Double?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setCloudConnection(unseenDuration: unseenDuration, for: $0)
        }
        touchAlertUpdatedAt(type: .cloudConnection(unseenDuration: 0), for: sensor)
        if let unseenDuration {
            postAlertDidChange(with: sensor, of: .cloudConnection(unseenDuration: unseenDuration))
        }
    }

    func cloudConnectionUnseenDuration(for sensor: PhysicalSensor) -> Double? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.cloudConnectionUnseenDuration(for: $0)
        }
    }
}

// MARK: - Movement

public extension RuuviServiceAlertImpl {
    func movementCounter(for sensor: PhysicalSensor) -> Int? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.movementCounter(for: $0)
        }
    }

    func setMovement(counter: Int?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setMovement(counter: counter, for: $0)
        }
        // no need to post an update, this is not user initiated action
    }

    func movementDescription(for sensor: PhysicalSensor) -> String? {
        alertIdentifierValue(for: sensor) {
            alertPersistence.movementDescription(for: $0)
        }
    }

    func setMovement(description: String?, for sensor: PhysicalSensor) {
        updateAlertIdentifiers(for: sensor) {
            alertPersistence.setMovement(description: description, for: $0)
        }

        touchAlertUpdatedAt(type: .movement(last: 0), for: sensor)
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
