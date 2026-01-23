// swiftlint:disable file_length
import Foundation
import RuuviOntology
import RuuviLocalization
import RuuviService

// MARK: - Process Physical Sensors

public extension RuuviNotifierImpl {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func process(record: RuuviTagSensorRecord, trigger: Bool) {
        guard let luid = record.luid,
              ruuviAlertService.hasRegistrations(for: record)
        else {
            return
        }
        var isTriggered = false
        AlertType.allCases.forEach { type in
            switch type {
            case .temperature:
                let isTemperature = process(
                    temperature: record.temperature,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isTemperature
                notify(alertType: type, uuid: luid.value, isTriggered: isTemperature)
            case .relativeHumidity:
                let isRelativeHumidity = process(
                    relativeHumidity: record.humidity,
                    temperature: record.temperature,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isRelativeHumidity
                notify(alertType: type, uuid: luid.value, isTriggered: isRelativeHumidity)
            case .humidity:
                let isAbsoluteHumidity = process(
                    absoluteHumidity: record.humidity,
                    temperature: record.temperature,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isAbsoluteHumidity
                notify(alertType: type, uuid: luid.value, isTriggered: isAbsoluteHumidity)
            case .dewPoint:
                let isDewPoint = process(
                    dewPoint: record.humidity,
                    temperature: record.temperature,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isDewPoint
                notify(alertType: type, uuid: luid.value, isTriggered: isDewPoint)
            case .pressure:
                let isPressure = process(
                    pressure: record.pressure,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPressure
                notify(alertType: type, uuid: luid.value, isTriggered: isPressure)
            case .signal:
                let isSignal = process(
                    signal: record.rssi,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isSignal
                notify(alertType: type, uuid: luid.value, isTriggered: isSignal)
            case .batteryVoltage:
                let isBatteryVoltage = process(
                    batteryVoltage: record.voltage,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isBatteryVoltage
                notify(alertType: type, uuid: luid.value, isTriggered: isBatteryVoltage)
            case .aqi:
                let currentAQI = measurementService.aqi(
                    for: record.co2,
                    and: record.pm25
                )
                let isAQI = process(
                    aqi: currentAQI,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isAQI
                notify(alertType: type, uuid: luid.value, isTriggered: isAQI)
            case .carbonDioxide:
                let isCarbonDioxide = process(
                    carbonDioxide: record.co2,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isCarbonDioxide
                notify(alertType: type, uuid: luid.value, isTriggered: isCarbonDioxide)
            case .pMatter1:
                let isPM1 = process(
                    pMatter1: record.pm1,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPM1
                notify(alertType: type, uuid: luid.value, isTriggered: isPM1)
            case .pMatter25:
                let isPM25 = process(
                    pMatter25: record.pm25,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPM25
                notify(alertType: type, uuid: luid.value, isTriggered: isPM25)
            case .pMatter4:
                let isPM4 = process(
                    pMatter4: record.pm4,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPM4
                notify(alertType: type, uuid: luid.value, isTriggered: isPM4)
            case .pMatter10:
                let isPM10 = process(
                    pMatter10: record.pm10,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPM10
                notify(alertType: type, uuid: luid.value, isTriggered: isPM10)
            case .voc:
                let isVOC = process(
                    voc: record.voc,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isVOC
                notify(alertType: type, uuid: luid.value, isTriggered: isVOC)
            case .nox:
                let isNOX = process(
                    nox: record.nox,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isNOX
                notify(alertType: type, uuid: luid.value, isTriggered: isNOX)
            case .soundInstant:
                let isSound = process(
                    soundInstant: record.dbaInstant,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isSound
                notify(alertType: type, uuid: luid.value, isTriggered: isSound)
            case .soundAverage:
                let isSound = process(
                    soundAverage: record.dbaAvg,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isSound
                notify(alertType: type, uuid: luid.value, isTriggered: isSound)
            case .soundPeak:
                let isSound = process(
                    soundPeak: record.dbaPeak,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isSound
                notify(alertType: type, uuid: luid.value, isTriggered: isSound)
            case .luminosity:
                let isLuminosity = process(
                    luminosity: record.luminance,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isLuminosity
                notify(alertType: type, uuid: luid.value, isTriggered: isLuminosity)
            case .movement:
                let movementResult = process(
                    movement: type,
                    record: record,
                    trigger: trigger
                )
                isTriggered = isTriggered || movementResult.isTriggered
                notify(alertType: type, uuid: luid.value, isTriggered: movementResult.isTriggered)
                if let movementCounter = record.movementCounter, movementResult.didMove {
                    ruuviAlertService.setMovement(counter: movementCounter, for: record)
                }
            default:
                // do nothing, see RuuviTagHeartbeatDaemon
                break
            }
        }

        notify(uuid: luid.value, isTriggered: isTriggered)
    }
}

// MARK: - Process Network Sensors

public extension RuuviNotifierImpl {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func processNetwork(
        record: RuuviTagSensorRecord,
        trigger: Bool,
        for identifier: MACIdentifier
    ) {
        guard ruuviAlertService.hasRegistrations(for: record)
        else {
            return
        }

        var isTriggered = false
        AlertType.allCases.forEach { type in
            switch type {
            case .temperature:
                let isTemperature = process(
                    temperature: record.temperature,
                    alertType: type,
                    identifier: identifier,
                    trigger: trigger
                )
                isTriggered = isTriggered || isTemperature
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isTemperature
                )
            case .relativeHumidity:
                let isRelativeHumidity = process(
                    relativeHumidity: record.humidity,
                    temperature: record.temperature,
                    alertType: type,
                    identifier: identifier,
                    trigger: trigger
                )
                isTriggered = isTriggered || isRelativeHumidity
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isRelativeHumidity
                )
            case .humidity:
                let isAbsoluteHumidity = process(
                    absoluteHumidity: record.humidity,
                    temperature: record.temperature,
                    alertType: type,
                    identifier: identifier,
                    trigger: trigger
                )
                isTriggered = isTriggered || isAbsoluteHumidity
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isAbsoluteHumidity
                )
            case .dewPoint:
                let isDewPoint = process(
                    dewPoint: record.humidity,
                    temperature: record.temperature,
                    alertType: type,
                    identifier: identifier,
                    trigger: trigger
                )
                isTriggered = isTriggered || isDewPoint
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isDewPoint
                )
            case .pressure:
                let isPressure = process(
                    pressure: record.pressure,
                    alertType: type,
                    identifier: identifier,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPressure
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isPressure
                )
            case .signal:
                let isSignal = process(
                    signal: record.rssi,
                    alertType: type,
                    identifier: identifier,
                    trigger: trigger
                )
                isTriggered = isTriggered || isSignal
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isSignal
                )
            case .batteryVoltage:
                let isBatteryVoltage = process(
                    batteryVoltage: record.voltage,
                    alertType: type,
                    identifier: identifier,
                    trigger: trigger
                )
                isTriggered = isTriggered || isBatteryVoltage
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isBatteryVoltage
                )
            case .aqi:
                let currentAQI = measurementService.aqi(
                    for: record.co2,
                    and: record.pm25
                )
                let isAQI = process(
                    aqi: currentAQI,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isAQI
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isAQI
                )
            case .carbonDioxide:
                let isCarbonDioxide = process(
                    carbonDioxide: record.co2,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isCarbonDioxide
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isCarbonDioxide
                )
            case .pMatter1:
                let isPM1 = process(
                    pMatter1: record.pm1,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPM1
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isPM1
                )
            case .pMatter25:
                let isPM25 = process(
                    pMatter25: record.pm25,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPM25
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isPM25
                )
            case .pMatter4:
                let isPM4 = process(
                    pMatter4: record.pm4,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPM4
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isPM4
                )
            case .pMatter10:
                let isPM10 = process(
                    pMatter10: record.pm10,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPM10
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isPM10
                )
            case .voc:
                let isVOC = process(
                    voc: record.voc,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isVOC
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isVOC
                )
            case .nox:
                let isNOX = process(
                    nox: record.nox,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isNOX
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isNOX
                )
            case .soundInstant:
                let isSoundInstant = process(
                    soundInstant: record.dbaInstant,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isSoundInstant
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isSoundInstant
                )
            case .soundAverage:
                let isSoundAverage = process(
                    soundAverage: record.dbaAvg,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isSoundAverage
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isSoundAverage
                )
            case .soundPeak:
                let isSoundPeak = process(
                    soundPeak: record.dbaPeak,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isSoundPeak
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isSoundPeak
                )
            case .luminosity:
                let isLuminosity = process(
                    luminosity: record.luminance,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isLuminosity
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isLuminosity
                )
            case .cloudConnection:
                let isCloudConnection = processCloudConnection(
                    alertType: type,
                    identifier: identifier,
                    record: record
                )
                isTriggered = isTriggered || isCloudConnection
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isCloudConnection
                )
            default:
                break
            }
        }

        notify(uuid: identifier.value, isTriggered: isTriggered)
    }
}

// MARK: - Notify

extension RuuviNotifierImpl {
    private func notify(uuid: String, isTriggered: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            if let observers = sSelf.observations[uuid] {
                for i in 0 ..< observers.count {
                    if let pointer = observers.pointer(at: i),
                       let observer = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
                       as? RuuviNotifierObserver {
                        observer.ruuvi(
                            notifier: sSelf,
                            isTriggered: isTriggered,
                            for: uuid
                        )
                    }
                }
            }
        }
    }

    private func notify(alertType: AlertType, uuid: String, isTriggered: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            if let observers = sSelf.observations[uuid] {
                for i in 0 ..< observers.count {
                    if let pointer = observers.pointer(at: i),
                       let observer = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
                       as? RuuviNotifierObserver {
                        observer.ruuvi(
                            notifier: sSelf,
                            alertType: alertType,
                            isTriggered: isTriggered,
                            for: uuid
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Private

extension RuuviNotifierImpl {
    private func process(
        temperature: Temperature?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .temperature(lower, upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
           let l = Temperature(lower),
           let u = Temperature(upper),
           let t = temperature {
            let isLower = t < l
            let isUpper = t > u
            if trigger {
                if isLower {
                    let lowerString = measurementService.string(
                        for: l,
                        allowSettings: false
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .temperature(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowTemperature(lowerString)
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.string(
                        for: u,
                        allowSettings: false
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .temperature(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highTemperature(upperString)
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        relativeHumidity: Humidity?,
        temperature: Temperature?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .relativeHumidity(lower, upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
           let t = temperature,
           let rh = relativeHumidity?.converted(to: .relative(temperature: t)) {
            let isLower = rh.value < lower
            let isUpper = rh.value > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.stringWithoutSign(
                        humidity: lower*100
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .relativeHumidity(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowHumidity(
                                "\(lowerString) %"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.stringWithoutSign(
                        humidity: upper*100
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .relativeHumidity(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highHumidity(
                                "\(upperString) %"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        absoluteHumidity: Humidity?,
        temperature: Temperature?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier,
              let temperature,
              let absoluteHumidity
        else {
            return false
        }

        if case let .humidity(lower, upper) = ruuviAlertService.alert(for: identifier.value, of: alertType) {
            let humidityWithTemperature = absoluteHumidity
                .converted(to: .relative(temperature: temperature))
            let current = humidityWithTemperature.converted(to: .absolute)
            let lowerValue = lower.converted(to: .absolute).value
            let upperValue = upper.converted(to: .absolute).value

            let isLower = current.value < lowerValue
            let isUpper = current.value > upperValue
            if trigger {
                if isLower {
                    let lowerString = measurementService.stringWithoutSign(humidity: lowerValue)
                    let valueWithUnit = "\(lowerString) \(RuuviLocalization.gm³)"
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute),
                            for: identifier.value,
                            title: sSelf.titles.lowAbsoluteHumidity(valueWithUnit)
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.stringWithoutSign(humidity: upperValue)
                    let valueWithUnit = "\(upperString) \(RuuviLocalization.gm³)"
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute),
                            for: identifier.value,
                            title: sSelf.titles.highAbsoluteHumidity(valueWithUnit)
                        )
                    }
                }
            }
            return isLower || isUpper
        }

        return false
    }

    private func process(
        dewPoint: Humidity?,
        temperature: Temperature?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier,
              let temperature,
              let dewPoint
        else {
            return false
        }

        if case let .dewPoint(lower, upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
           let lowerTemperature = Temperature(lower),
           let upperTemperature = Temperature(upper),
           let dewPointTemperature = try? dewPoint
                .converted(to: .relative(temperature: temperature))
                .dewPoint(temperature: temperature) {
            let isLower = dewPointTemperature < lowerTemperature
            let isUpper = dewPointTemperature > upperTemperature
            if trigger {
                if isLower {
                    let lowerString = measurementService.string(
                        for: lowerTemperature,
                        allowSettings: false
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .dewPoint(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowDewPoint(lowerString)
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.string(
                        for: upperTemperature,
                        allowSettings: false
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .dewPoint(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highDewPoint(upperString)
                        )
                    }
                }
            }
            return isLower || isUpper
        }

        return false
    }

    private func process(
        pressure: Pressure?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .pressure(lower, upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
           let l = Pressure(lower),
           let u = Pressure(upper),
           let pressure {
            let isLower = pressure < l
            let isUpper = pressure > u
            if trigger {
                if isLower {
                    let lowerString = measurementService.string(
                        for: l, allowSettings: false
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .pressure(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowPressure(lowerString)
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.string(
                        for: u, allowSettings: false
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .pressure(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highPressure(upperString)
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        signal: Int?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .signal(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
            let signal {
            let isLower = Double(signal) < lower
            let isUpper = Double(signal) > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.string(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .signal(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowSignal(
                                "\(lowerString) \(RuuviLocalization.dBm)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.string(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .signal(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highSignal(
                                "\(upperString) \(RuuviLocalization.dBm)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        batteryVoltage: Voltage?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .batteryVoltage(lower, upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
           let voltage = batteryVoltage {
            let l = Voltage(value: lower, unit: .volts)
            let u = Voltage(value: upper, unit: .volts)
            let isLower = voltage < l
            let isUpper = voltage > u
            if trigger {
                if isLower {
                    let lowerString = measurementService.string(for: l)
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .batteryVoltage(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowBatteryVoltage(lowerString)
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.string(for: u)
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .batteryVoltage(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highBatteryVoltage(upperString)
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        aqi: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .aqi(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let aqi {
            let isLower = aqi < lower
            let isUpper = aqi > upper
            if trigger {
                if isLower {
                    // TODO:
                    let lowerString = measurementService.co2String(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .aqi(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowAQI(
                                "\(lowerString) %"
                            )
                        )
                    }
                } else if isUpper {
                    // TODO:
                    let upperString = measurementService.co2String(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .aqi(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highAQI(
                                "\(upperString) %"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        carbonDioxide: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .carbonDioxide(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let carbonDioxide {
            let isLower = carbonDioxide < lower
            let isUpper = carbonDioxide > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.co2String(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .carbonDioxide(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowCarbonDioxide(
                                "\(lowerString) \(RuuviLocalization.unitCo2)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.co2String(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .carbonDioxide(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highCarbonDioxide(
                                "\(upperString) \(RuuviLocalization.unitCo2)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        pMatter1: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .pMatter1(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let pMatter1 {
            let isLower = pMatter1 < lower
            let isUpper = pMatter1 > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.pm10String(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .pMatter1(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowPMatter1(
                                "\(lowerString) \(RuuviLocalization.unitPm10)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.pm10String(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .pMatter1(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highPMatter1(
                                "\(upperString) \(RuuviLocalization.unitPm10)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        pMatter25: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .pMatter25(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let pMatter25 {
            let isLower = pMatter25 < lower
            let isUpper = pMatter25 > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.pm25String(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .pMatter25(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowPMatter25(
                                "\(lowerString) \(RuuviLocalization.unitPm25)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.pm25String(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .pMatter25(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highPMatter25(
                                "\(upperString) \(RuuviLocalization.unitPm25)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        pMatter4: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .pMatter4(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let pMatter4 {
            let isLower = pMatter4 < lower
            let isUpper = pMatter4 > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.pm40String(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .pMatter4(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowPMatter4(
                                "\(lowerString) \(RuuviLocalization.unitPm40)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.pm40String(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .pMatter4(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highPMatter4(
                                "\(upperString) \(RuuviLocalization.unitPm40)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        pMatter10: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .pMatter10(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let pMatter10 {
            let isLower = pMatter10 < lower
            let isUpper = pMatter10 > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.pm100String(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .pMatter10(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowPMatter10(
                                "\(lowerString) \(RuuviLocalization.unitPm100)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.pm100String(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .pMatter10(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highPMatter10(
                                "\(upperString) \(RuuviLocalization.unitPm100)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        voc: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .voc(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let voc {
            let isLower = voc < lower
            let isUpper = voc > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.vocString(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .voc(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowVOC(
                                "\(lowerString) \(RuuviLocalization.unitVoc)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.vocString(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .voc(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highVOC(
                                "\(upperString) \(RuuviLocalization.unitVoc)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        nox: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .nox(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let nox {
            let isLower = nox < lower
            let isUpper = nox > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.noxString(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .nox(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowNOx(
                                "\(lowerString) \(RuuviLocalization.unitNox)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.noxString(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .nox(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highNOx(
                                "\(upperString) \(RuuviLocalization.unitNox)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        soundInstant: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .soundInstant(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let soundInstant {
            let isLower = soundInstant < lower
            let isUpper = soundInstant > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.soundString(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .soundInstant(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowSoundInstant(
                                "\(lowerString) \(RuuviLocalization.unitSound)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.soundString(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .soundInstant(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highSoundInstant(
                                "\(upperString) \(RuuviLocalization.unitSound)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        soundAverage: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .soundAverage(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let soundAverage {
            let isLower = soundAverage < lower
            let isUpper = soundAverage > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.soundString(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .soundAverage(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowSoundAverage(
                                "\(lowerString) \(RuuviLocalization.unitSound)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.soundString(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .soundAverage(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highSoundAverage(
                                "\(upperString) \(RuuviLocalization.unitSound)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        soundPeak: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .soundInstant(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let soundPeak {
            let isLower = soundPeak < lower
            let isUpper = soundPeak > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.soundString(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .soundPeak(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowSoundPeak(
                                "\(lowerString) \(RuuviLocalization.unitSound)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.soundString(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .soundPeak(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highSoundPeak(
                                "\(upperString) \(RuuviLocalization.unitSound)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        luminosity: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .luminosity(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let luminosity {
            let isLower = luminosity < lower
            let isUpper = luminosity > upper
            if trigger {
                if isLower {
                    let lowerString = measurementService.luminosityString(
                        for: lower
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .luminosity(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.lowLuminosity(
                                "\(lowerString) \(RuuviLocalization.unitLuminosity)"
                            )
                        )
                    }
                } else if isUpper {
                    let upperString = measurementService.luminosityString(
                        for: upper
                    )
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .luminosity(lower: 0, upper: 0),
                            for: identifier.value,
                            title: sSelf.titles.highLuminosity(
                                "\(upperString) \(RuuviLocalization.unitLuminosity)"
                            )
                        )
                    }
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        movement: AlertType,
        record: RuuviTagSensorRecord,
        trigger: Bool = true
    ) -> (isTriggered: Bool, didMove: Bool) {
        guard let luid = record.luid else { return (false, false) }
        guard case let .movement(last) = ruuviAlertService.alert(for: luid.value, of: movement) else {
            clearMovementHysteresis(for: luid.value)
            return (false, false)
        }

        let didMove: Bool
        if let movementCounter = record.movementCounter {
            if last == 0, movementCounter > 0 {
                ruuviAlertService.setMovement(counter: movementCounter, for: record)
                didMove = false
            } else {
                didMove = movementCounter > last
            }
            if trigger, didMove {
                DispatchQueue.main.async { [weak self] in
                    guard let sSelf = self else { return }
                    sSelf.localNotificationsManager
                        .notifyDidMove(
                            for: luid.value,
                            counter: movementCounter,
                            title: sSelf.titles.didMove
                        )
                }
            }
            if didMove {
                updateMovementHysteresis(for: luid.value, eventDate: record.date)
            }
        } else {
            didMove = false
        }

        let isTriggered = didMove || isMovementHysteresisActive(for: luid.value, now: Date())
        return (isTriggered, didMove)
    }

    private func movementHysteresisInterval() -> TimeInterval {
        let minutes = settings.movementAlertHysteresisMinutes
        guard minutes > 0 else { return 0 }
        return TimeInterval(minutes) * 60
    }

    func restoreMovementHysteresisState() {
        let interval = movementHysteresisInterval()
        let now = Date()
        let didMutate = withHysteresisState { () -> Bool in
            var mutated = false
            movementAlertHysteresisLastEventByUUID = settings.movementAlertHysteresisLastEvents()
            let beforeCount = movementAlertHysteresisLastEventByUUID.count
            movementAlertHysteresisLastEventByUUID = movementAlertHysteresisLastEventByUUID.filter {
                ruuviAlertService.isOn(type: .movement(last: 0), for: $0.key)
            }
            if movementAlertHysteresisLastEventByUUID.count != beforeCount {
                mutated = true
            }
            if interval <= 0 {
                if !movementAlertHysteresisLastEventByUUID.isEmpty {
                    movementAlertHysteresisLastEventByUUID.removeAll()
                    mutated = true
                }
            } else {
                let before = movementAlertHysteresisLastEventByUUID.count
                movementAlertHysteresisLastEventByUUID = movementAlertHysteresisLastEventByUUID.filter {
                    $0.value.addingTimeInterval(interval) > now
                }
                mutated = movementAlertHysteresisLastEventByUUID.count != before
            }
            return mutated
        }
        if didMutate {
            persistMovementHysteresisState()
        }
        scheduleMovementHysteresisTimerIfNeeded()
    }

    public func clearMovementAlertHysteresis(for uuid: String) {
        clearMovementHysteresis(for: uuid)
        notify(alertType: .movement(last: 0), uuid: uuid, isTriggered: false)
    }

    private func updateMovementHysteresis(for uuid: String, eventDate: Date) {
        let interval = movementHysteresisInterval()
        let didMutate = withHysteresisState { () -> Bool in
            guard interval > 0 else {
                return movementAlertHysteresisLastEventByUUID.removeValue(forKey: uuid) != nil
            }
            let safeDate = min(eventDate, Date())
            if let existingDate = movementAlertHysteresisLastEventByUUID[uuid],
               existingDate > safeDate {
                return false
            }
            movementAlertHysteresisLastEventByUUID[uuid] = safeDate
            return true
        }
        if didMutate {
            persistMovementHysteresisState()
            scheduleMovementHysteresisTimerIfNeeded()
        }
    }

    private func isMovementHysteresisActive(for uuid: String, now: Date) -> Bool {
        let interval = movementHysteresisInterval()
        let (isActive, didMutate) = withHysteresisState { () -> (Bool, Bool) in
            guard interval > 0 else {
                let mutated = movementAlertHysteresisLastEventByUUID.removeValue(forKey: uuid) != nil
                return (false, mutated)
            }
            guard let lastEvent = movementAlertHysteresisLastEventByUUID[uuid] else {
                return (false, false)
            }
            let expiry = lastEvent.addingTimeInterval(interval)
            if expiry > now {
                return (true, false)
            }
            movementAlertHysteresisLastEventByUUID.removeValue(forKey: uuid)
            return (false, true)
        }
        if didMutate {
            persistMovementHysteresisState()
            scheduleMovementHysteresisTimerIfNeeded()
        }
        return isActive
    }

    public func clearMovementHysteresis(for uuid: String) {
        let didMutate = withHysteresisState {
            movementAlertHysteresisLastEventByUUID.removeValue(forKey: uuid) != nil
        }
        if didMutate {
            persistMovementHysteresisState()
            scheduleMovementHysteresisTimerIfNeeded()
        }
    }

    private func scheduleMovementHysteresisTimerIfNeeded() {
        let interval = movementHysteresisInterval()
        let nextExpiry: Date? = withHysteresisState {
            guard interval > 0 else { return nil }
            var expiry: Date?
            for (_, lastEvent) in movementAlertHysteresisLastEventByUUID {
                let eventExpiry = lastEvent.addingTimeInterval(interval)
                if let current = expiry {
                    if eventExpiry < current {
                        expiry = eventExpiry
                    }
                } else {
                    expiry = eventExpiry
                }
            }
            return expiry
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.movementAlertHysteresisTimer?.invalidate()
            self.movementAlertHysteresisTimer = nil
            guard let nextExpiry else { return }
            let delay = max(0.1, nextExpiry.timeIntervalSinceNow)
            self.movementAlertHysteresisTimer = Timer.scheduledTimer(
                withTimeInterval: delay,
                repeats: false
            ) { [weak self] _ in
                self?.handleMovementHysteresisTimerFired()
            }
        }
    }

    private func handleMovementHysteresisTimerFired() {
        let now = Date()
        let interval = movementHysteresisInterval()
        let (expiredUUIDs, didMutate) = withHysteresisState { () -> ([String], Bool) in
            if interval <= 0 {
                if !movementAlertHysteresisLastEventByUUID.isEmpty {
                    movementAlertHysteresisLastEventByUUID.removeAll()
                    return ([], true)
                }
                return ([], false)
            } else {
                var expired = [String]()
                for (uuid, lastEvent) in movementAlertHysteresisLastEventByUUID {
                    let expiry = lastEvent.addingTimeInterval(interval)
                    if expiry <= now {
                        expired.append(uuid)
                    }
                }
                for uuid in expired {
                    movementAlertHysteresisLastEventByUUID.removeValue(forKey: uuid)
                }
                return (expired, !expired.isEmpty)
            }
        }

        if didMutate {
            persistMovementHysteresisState()
        }
        if !expiredUUIDs.isEmpty {
            expiredUUIDs.forEach { uuid in
                notify(alertType: .movement(last: 0), uuid: uuid, isTriggered: false)
            }
        }

        scheduleMovementHysteresisTimerIfNeeded()
    }

    private func persistMovementHysteresisState() {
        let snapshot = withHysteresisState { movementAlertHysteresisLastEventByUUID }
        settings.setMovementAlertHysteresisLastEvents(snapshot)
    }

    private func processCloudConnection(
        alertType: AlertType,
        identifier: MACIdentifier?,
        record: RuuviTagSensorRecord
    ) -> Bool {
        guard let identifier else { return false }

        if case let .cloudConnection(unseenDuration) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ) {
            let calendar = Calendar.current
            let thresholdDateTime = calendar.date(
                byAdding: .second, value: -Int(unseenDuration), to: Date()
            ) ?? Date()

            // Check the last successful system sync with the cloud
            if let lastSystemCloudSyncDate = localSyncState.getSyncDate() {
                // If the sync date is earlier than our threshold, don't trigger the alert
                if lastSystemCloudSyncDate < thresholdDateTime {
                    return false
                }
            }

            // If the measurement date is earlier than our threshold, trigger the alert
            return record.date < thresholdDateTime
        }

        // Default case, don't trigger alert
        return false
    }
}
