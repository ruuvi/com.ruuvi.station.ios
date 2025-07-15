// swiftlint:disable file_length
import Foundation
import Future
import RuuviCloud
import RuuviLocal
import RuuviOntology

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
            case let .sound(lower, upper):
                cloud.setAlert(
                    type: .sound,
                    settingType: .state,
                    isEnabled: true,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: soundDescription(for: ruuviTag),
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
            case let .sound(lower, upper):
                cloud.setAlert(
                    type: .sound,
                    settingType: .state,
                    isEnabled: false,
                    min: lower,
                    max: upper,
                    counter: nil,
                    delay: nil,
                    description: noxDescription(for: ruuviTag),
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

    // MARK: - Sound
    func setLower(sound: Double?, ruuviTag: RuuviTagSensor) {
        setLower(sound: sound, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .sound,
                settingType: .lowerBound,
                isEnabled: isOn(
                    type: .sound(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: sound ?? 0,
                max: upperSound(for: ruuviTag) ?? 0,
                counter: nil,
                delay: nil,
                description: soundDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setUpper(sound: Double?, ruuviTag: RuuviTagSensor) {
        setUpper(sound: sound, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .sound,
                settingType: .upperBound,
                isEnabled: isOn(
                    type: .sound(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerSound(for: ruuviTag) ?? 0,
                max: sound ?? 0,
                counter: nil,
                delay: nil,
                description: soundDescription(for: ruuviTag),
                for: macId
            )
        }
    }

    func setSound(description: String?, ruuviTag: RuuviTagSensor) {
        setSound(description: description, for: ruuviTag)
        if ruuviTag.isCloud, let macId = ruuviTag.macId {
            cloud.setAlert(
                type: .sound,
                settingType: .description,
                isEnabled: isOn(
                    type: .sound(lower: 0, upper: 0),
                    for: ruuviTag
                ),
                min: lowerSound(for: ruuviTag) ?? 0,
                max: upperSound(for: ruuviTag) ?? 0,
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
                case .co2:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .carbonDioxide(
                        lower: min,
                        upper: max
                    )
                    setCarbonDioxide(
                        description: cloudAlert.description,
                        for: physicalSensor
                    )
                case .pm10:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .pMatter1(
                        lower: min,
                        upper: max
                    )
                    setPM1(
                        description: cloudAlert.description,
                        for: physicalSensor
                    )
                case .pm25:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .pMatter25(
                        lower: min,
                        upper: max
                    )
                    setPM25(
                        description: cloudAlert.description,
                        for: physicalSensor
                    )
                case .pm40:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .pMatter4(
                        lower: min,
                        upper: max
                    )
                    setPM4(
                        description: cloudAlert.description,
                        for: physicalSensor
                    )
                case .pm100:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .pMatter10(
                        lower: min,
                        upper: max
                    )
                    setPM10(
                        description: cloudAlert.description,
                        for: physicalSensor
                    )
                case .voc:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .voc(
                        lower: min,
                        upper: max
                    )
                    setVOC(
                        description: cloudAlert.description,
                        for: physicalSensor
                    )
                case .nox:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .nox(
                        lower: min,
                        upper: max
                    )
                    setNOX(
                        description: cloudAlert.description,
                        for: physicalSensor
                    )
                case .sound:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .sound(
                        lower: min,
                        upper: max
                    )
                    setSound(
                        description: cloudAlert.description,
                        for: physicalSensor
                    )
                case .luminosity:
                    guard let min = cloudAlert.min, let max = cloudAlert.max else { return }
                    type = .luminosity(
                        lower: min,
                        upper: max
                    )
                    setLuminosity(
                        description: cloudAlert.description,
                        for: physicalSensor
                    )
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

    private func setUpper(celsius: Double?, for sensor: PhysicalSensor) {
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

    private func setTemperature(description: String?, for sensor: PhysicalSensor) {
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

    private func setUpper(relativeHumidity: Double?, for sensor: PhysicalSensor) {
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

    private func setRelativeHumidity(description: String?, for sensor: PhysicalSensor) {
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

    private func setUpper(pressure: Double?, for sensor: PhysicalSensor) {
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

    private func setPressure(description: String?, for sensor: PhysicalSensor) {
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

    private func setUpper(signal: Double?, for sensor: PhysicalSensor) {
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

    private func setSignal(description: String?, for sensor: PhysicalSensor) {
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
}

// MARK: - Carbon Dioxide

public extension RuuviServiceAlertImpl {

    func lowerCarbonDioxide(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerCarbonDioxide(for: luid.value)
                ?? alertPersistence.lowerCarbonDioxide(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerCarbonDioxide(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerCarbonDioxide(for: macId.value)
        } else {
            return nil
        }
    }

    func upperCarbonDioxide(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperCarbonDioxide(for: luid.value)
            ?? alertPersistence.upperCarbonDioxide(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperCarbonDioxide(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperCarbonDioxide(for: macId.value)
        } else {
            return nil
        }
    }

    func carbonDioxideDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.carbonDioxideDescription(for: luid.value)
            ?? alertPersistence.carbonDioxideDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.carbonDioxideDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.carbonDioxideDescription(for: macId.value)
        } else {
            return nil
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
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(carbonDioxide: carbonDioxide, for: luid.value)
            alertPersistence.setLower(carbonDioxide: carbonDioxide, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(carbonDioxide: carbonDioxide, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(carbonDioxide: carbonDioxide, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = carbonDioxide, let u = upperCarbonDioxide(for: sensor) {
            postAlertDidChange(
                with: sensor,
                of: .carbonDioxide(lower: l, upper: u)
            )
        }
    }

    private func setUpper(carbonDioxide: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(carbonDioxide: carbonDioxide, for: luid.value)
            alertPersistence.setUpper(carbonDioxide: carbonDioxide, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(carbonDioxide: carbonDioxide, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(carbonDioxide: carbonDioxide, for: macId.value)
        } else {
            assertionFailure()
        }

        if let l = lowerCarbonDioxide(for: sensor), let u = carbonDioxide {
            postAlertDidChange(
                with: sensor,
                of: .carbonDioxide(lower: l, upper: u)
            )
        }
    }

    private func setCarbonDioxide(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setCarbonDioxide(description: description, for: luid.value)
            alertPersistence.setCarbonDioxide(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setCarbonDioxide(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setCarbonDioxide(description: description, for: macId.value)
        } else {
            assertionFailure()
        }

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
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerPM1(for: luid.value)
                ?? alertPersistence.lowerPM1(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerPM1(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerPM1(for: macId.value)
        } else {
            return nil
        }
    }

    func upperPM1(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperPM1(for: luid.value)
                ?? alertPersistence.upperPM1(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperPM1(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperPM1(for: macId.value)
        } else {
            return nil
        }
    }

    func pm1Description(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.pm1Description(for: luid.value)
                ?? alertPersistence.pm1Description(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.pm1Description(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.pm1Description(for: macId.value)
        } else {
            return nil
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
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(pm1: pm1, for: luid.value)
            alertPersistence.setLower(pm1: pm1, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(pm1: pm1, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(pm1: pm1, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setUpper(pm1: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(pm1: pm1, for: luid.value)
            alertPersistence.setUpper(pm1: pm1, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(pm1: pm1, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(pm1: pm1, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setPM1(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setPM1(description: description, for: luid.value)
            alertPersistence.setPM1(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setPM1(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setPM1(description: description, for: macId.value)
        } else {
            assertionFailure()
        }
    }
}

// MARK: - PM2.5
public extension RuuviServiceAlertImpl {
    func lowerPM25(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerPM25(for: luid.value)
                ?? alertPersistence.lowerPM25(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerPM25(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerPM25(for: macId.value)
        } else {
            return nil
        }
    }

    func upperPM25(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperPM25(for: luid.value)
                ?? alertPersistence.upperPM25(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperPM25(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperPM25(for: macId.value)
        } else {
            return nil
        }
    }

    func pm25Description(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.pm25Description(for: luid.value)
                ?? alertPersistence.pm25Description(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.pm25Description(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.pm25Description(for: macId.value)
        } else {
            return nil
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
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(pm25: pm25, for: luid.value)
            alertPersistence.setLower(pm25: pm25, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(pm25: pm25, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(pm25: pm25, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setUpper(pm25: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(pm25: pm25, for: luid.value)
            alertPersistence.setUpper(pm25: pm25, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(pm25: pm25, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(pm25: pm25, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setPM25(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setPM25(description: description, for: luid.value)
            alertPersistence.setPM25(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setPM25(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setPM25(description: description, for: macId.value)
        } else {
            assertionFailure()
        }
    }
}

// MARK: - PM4
public extension RuuviServiceAlertImpl {
    func lowerPM4(for sensor: PhysicalSensor) -> Double? {
      if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerPM4(for: luid.value)
                ?? alertPersistence.lowerPM4(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerPM4(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerPM4(for: macId.value)
        } else {
            return nil
        }
    }

    func upperPM4(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperPM4(for: luid.value)
            ?? alertPersistence.upperPM4(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperPM4(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperPM4(for: macId.value)
        } else {
            return nil
        }
    }

    func pm4Description(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.pm4Description(for: luid.value)
                ?? alertPersistence.pm4Description(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.pm4Description(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.pm4Description(for: macId.value)
        } else {
            return nil
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
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(pm4: pm4, for: luid.value)
            alertPersistence.setLower(pm4: pm4, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(pm4: pm4, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(pm4: pm4, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setUpper(pm4: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(pm4: pm4, for: luid.value)
            alertPersistence.setUpper(pm4: pm4, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(pm4: pm4, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(pm4: pm4, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setPM4(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setPM4(description: description, for: luid.value)
            alertPersistence.setPM4(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setPM4(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setPM4(description: description, for: macId.value)
        } else {
            assertionFailure()
        }
    }
}

// MARK: - PM10
public extension RuuviServiceAlertImpl {
    func lowerPM10(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerPM10(for: luid.value)
                ?? alertPersistence.lowerPM10(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerPM10(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerPM10(for: macId.value)
        } else {
            return nil
        }
    }

    func upperPM10(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperPM10(for: luid.value)
            ?? alertPersistence.upperPM10(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperPM10(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperPM10(for: macId.value)
        } else {
            return nil
        }
    }

    func pm10Description(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.pm10Description(for: luid.value)
                ?? alertPersistence.pm10Description(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.pm10Description(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.pm10Description(for: macId.value)
        } else {
            return nil
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
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(pm10: pm10, for: luid.value)
            alertPersistence.setLower(pm10: pm10, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(pm10: pm10, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(pm10: pm10, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setUpper(pm10: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(pm10: pm10, for: luid.value)
            alertPersistence.setUpper(pm10: pm10, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(pm10: pm10, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(pm10: pm10, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setPM10(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setPM10(description: description, for: luid.value)
            alertPersistence.setPM10(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setPM10(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setPM10(description: description, for: macId.value)
        } else {
            assertionFailure()
        }
    }
}

// MARK: - VOC
public extension RuuviServiceAlertImpl {
    func lowerVOC(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerVOC(for: luid.value)
                ?? alertPersistence.lowerVOC(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerVOC(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerVOC(for: macId.value)
        } else {
            return nil
        }
    }

    func upperVOC(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperVOC(for: luid.value)
                ?? alertPersistence.upperVOC(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperVOC(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperVOC(for: macId.value)
        } else {
            return nil
        }
    }

    func vocDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.vocDescription(for: luid.value)
                ?? alertPersistence.vocDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.vocDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.vocDescription(for: macId.value)
        } else {
            return nil
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
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(voc: voc, for: luid.value)
            alertPersistence.setLower(voc: voc, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(voc: voc, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(voc: voc, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setUpper(voc: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(voc: voc, for: luid.value)
            alertPersistence.setUpper(voc: voc, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(voc: voc, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(voc: voc, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setVOC(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setVOC(description: description, for: luid.value)
            alertPersistence.setVOC(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setVOC(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setVOC(description: description, for: macId.value)
        } else {
            assertionFailure()
        }
    }
}

// MARK: - NOX
public extension RuuviServiceAlertImpl {

    func lowerNOX(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerNOX(for: luid.value)
                ?? alertPersistence.lowerNOX(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerNOX(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerNOX(for: macId.value)
        } else {
            return nil
        }
    }

    func upperNOX(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperNOX(for: luid.value)
                ?? alertPersistence.upperNOX(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperNOX(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperNOX(for: macId.value)
        } else {
            return nil
        }
    }

    func noxDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.noxDescription(for: luid.value)
                ?? alertPersistence.noxDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.noxDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.noxDescription(for: macId.value)
        } else {
            return nil
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
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(nox: nox, for: luid.value)
            alertPersistence.setLower(nox: nox, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(nox: nox, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(nox: nox, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setUpper(nox: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(nox: nox, for: luid.value)
            alertPersistence.setUpper(nox: nox, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(nox: nox, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(nox: nox, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setNOX(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setNOX(description: description, for: luid.value)
            alertPersistence.setNOX(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setNOX(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setNOX(description: description, for: macId.value)
        } else {
            assertionFailure()
        }
    }
}

// MARK: - Sound
public extension RuuviServiceAlertImpl {

    func lowerSound(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerSound(for: luid.value)
                ?? alertPersistence.lowerSound(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerSound(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerSound(for: macId.value)
        } else {
            return nil
        }
    }

    func upperSound(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperSound(for: luid.value)
                ?? alertPersistence.upperSound(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperSound(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperSound(for: macId.value)
        } else {
            return nil
        }
    }

    func soundDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.soundDescription(for: luid.value)
                ?? alertPersistence.soundDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.soundDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.soundDescription(for: macId.value)
        } else {
            return nil
        }
    }

    func lowerSound(for uuid: String) -> Double? {
        alertPersistence.lowerSound(for: uuid)
    }

    func upperSound(for uuid: String) -> Double? {
        alertPersistence.upperSound(for: uuid)
    }

    func soundDescription(for uuid: String) -> String? {
        alertPersistence.soundDescription(for: uuid)
    }

    // Private helpers
    private func setLower(sound: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(sound: sound, for: luid.value)
            alertPersistence.setLower(sound: sound, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(sound: sound, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(sound: sound, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setUpper(sound: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(sound: sound, for: luid.value)
            alertPersistence.setUpper(sound: sound, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(sound: sound, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(sound: sound, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setSound(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setSound(description: description, for: luid.value)
            alertPersistence.setSound(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setSound(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setSound(description: description, for: macId.value)
        } else {
            assertionFailure()
        }
    }
}

// MARK: - Luminosity
public extension RuuviServiceAlertImpl {
    func lowerLuminosity(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.lowerLuminosity(for: luid.value)
                ?? alertPersistence.lowerLuminosity(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.lowerLuminosity(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.lowerLuminosity(for: macId.value)
        } else {
            return nil
        }
    }

    func upperLuminosity(for sensor: PhysicalSensor) -> Double? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.upperLuminosity(for: luid.value)
                ?? alertPersistence.upperLuminosity(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.upperLuminosity(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.upperLuminosity(for: macId.value)
        } else {
            return nil
        }
    }

    func luminosityDescription(for sensor: PhysicalSensor) -> String? {
        if let luid = sensor.luid, let macId = sensor.macId {
            return alertPersistence.luminosityDescription(for: luid.value)
                ?? alertPersistence.luminosityDescription(for: macId.value)
        } else if let luid = sensor.luid {
            return alertPersistence.luminosityDescription(for: luid.value)
        } else if let macId = sensor.macId {
            return alertPersistence.luminosityDescription(for: macId.value)
        } else {
            return nil
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
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLower(luminosity: luminosity, for: luid.value)
            alertPersistence.setLower(luminosity: luminosity, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLower(luminosity: luminosity, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLower(luminosity: luminosity, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setUpper(luminosity: Double?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setUpper(luminosity: luminosity, for: luid.value)
            alertPersistence.setUpper(luminosity: luminosity, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setUpper(luminosity: luminosity, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setUpper(luminosity: luminosity, for: macId.value)
        } else {
            assertionFailure()
        }
    }

    private func setLuminosity(description: String?, for sensor: PhysicalSensor) {
        if let luid = sensor.luid, let macId = sensor.macId {
            alertPersistence.setLuminosity(description: description, for: luid.value)
            alertPersistence.setLuminosity(description: description, for: macId.value)
        } else if let luid = sensor.luid {
            alertPersistence.setLuminosity(description: description, for: luid.value)
        } else if let macId = sensor.macId {
            alertPersistence.setLuminosity(description: description, for: macId.value)
        } else {
            assertionFailure()
        }
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
