// swiftlint:disable file_length
import Foundation
import RuuviOntology

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
            case .pMatter2_5:
                let isPM2_5 = process(
                    pMatter2_5: record.pm2_5,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPM2_5
                notify(alertType: type, uuid: luid.value, isTriggered: isPM2_5)
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
            case .sound:
                let isSound = process(
                    sound: record.dbaAvg,
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
                let isMovement = process(
                    movement: type,
                    record: record,
                    trigger: trigger
                )
                isTriggered = isTriggered || isMovement
                notify(alertType: type, uuid: luid.value, isTriggered: isMovement)
            default:
                // do nothing, see RuuviTagHeartbeatDaemon
                break
            }
        }

        if let movementCounter = record.movementCounter {
            ruuviAlertService.setMovement(counter: movementCounter, for: record)
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
            case .pMatter2_5:
                let isPM2_5 = process(
                    pMatter2_5: record.pm2_5,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isPM2_5
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isPM2_5
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
            case .sound:
                let isSound = process(
                    sound: record.dbaAvg,
                    alertType: type,
                    identifier: record.luid,
                    trigger: trigger
                )
                isTriggered = isTriggered || isSound
                notify(
                    alertType: type,
                    uuid: identifier.value,
                    isTriggered: isSound
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
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        self?.localNotificationsManager.notify(
                            .low,
                            .temperature,
                            for: identifier.value,
                            title: sSelf.titles.lowTemperature
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .temperature,
                            for: identifier.value,
                            title: sSelf.titles.highTemperature
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
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .relativeHumidity,
                            for: identifier.value,
                            title: sSelf.titles.lowHumidity
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .relativeHumidity,
                            for: identifier.value,
                            title: sSelf.titles.highHumidity
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
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .pressure,
                            for: identifier.value,
                            title: sSelf.titles.lowPressure
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .pressure,
                            for: identifier.value,
                            title: sSelf.titles.highPressure
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
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .signal,
                            for: identifier.value,
                            title: sSelf.titles.lowSignal
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .signal,
                            for: identifier.value,
                            title: sSelf.titles.highSignal
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
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .carbonDioxide,
                            for: identifier.value,
                            title: sSelf.titles.lowCarbonDioxide
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .carbonDioxide,
                            for: identifier.value,
                            title: sSelf.titles.highCarbonDioxide
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
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .pMatter1,
                            for: identifier.value,
                            title: sSelf.titles.lowPMatter1
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .pMatter1,
                            for: identifier.value,
                            title: sSelf.titles.highPMatter1
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
        pMatter2_5: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .pMatter2_5(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let pMatter2_5 {
            let isLower = pMatter2_5 < lower
            let isUpper = pMatter2_5 > upper
            if trigger {
                if isLower {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .pMatter2_5,
                            for: identifier.value,
                            title: sSelf.titles.lowPMatter2_5
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .pMatter2_5,
                            for: identifier.value,
                            title: sSelf.titles.highPMatter2_5
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
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .pMatter4,
                            for: identifier.value,
                            title: sSelf.titles.lowPMatter4
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .pMatter4,
                            for: identifier.value,
                            title: sSelf.titles.highPMatter4
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
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .pMatter10,
                            for: identifier.value,
                            title: sSelf.titles.lowPMatter10
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .pMatter10,
                            for: identifier.value,
                            title: sSelf.titles.highPMatter10
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
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .voc,
                            for: identifier.value,
                            title: sSelf.titles.lowVOC
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .voc,
                            for: identifier.value,
                            title: sSelf.titles.highVOC
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
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .nox,
                            for: identifier.value,
                            title: sSelf.titles.lowNOx
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .nox,
                            for: identifier.value,
                            title: sSelf.titles.highNOx
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
        sound: Double?,
        alertType: AlertType,
        identifier: Identifier?,
        trigger: Bool = true
    ) -> Bool {
        guard let identifier else { return false }
        if case let .sound(lower, upper) = ruuviAlertService
            .alert(
                for: identifier.value,
                of: alertType
            ),
           let sound {
            let isLower = sound < lower
            let isUpper = sound > upper
            if trigger {
                if isLower {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .sound,
                            for: identifier.value,
                            title: sSelf.titles.lowSound
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .sound,
                            for: identifier.value,
                            title: sSelf.titles.highSound
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
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .low,
                            .luminosity,
                            for: identifier.value,
                            title: sSelf.titles.lowLuminosity
                        )
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        guard let sSelf = self else { return }
                        sSelf.localNotificationsManager.notify(
                            .high,
                            .luminosity,
                            for: identifier.value,
                            title: sSelf.titles.highLuminosity
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
    ) -> Bool {
        guard let luid = record.luid else { return false }
        if case let .movement(last) = ruuviAlertService.alert(for: luid.value, of: movement),
           let movementCounter = record.movementCounter {
            let isGreater = movementCounter > last
            if trigger {
                if isGreater {
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
            }
            return isGreater
        } else {
            return false
        }
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
