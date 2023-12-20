// swiftlint:disable file_length
import Foundation
import RuuviOntology

// MARK: - Process Physical Sensors

public extension RuuviNotifierImpl {
    // swiftlint:disable:next function_body_length
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
    // swiftlint:disable:next function_body_length
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
            case .cloudConnection:
                let isCloudConnection = processCloudConnection(
                    alertType: type,
                    identifier: identifier
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
        identifier: MACIdentifier?
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

            // If the system sync is within our threshold, check the measurement date
            if let measurementDate = localSyncState.getSyncDate(for: identifier) {
                // If the measurement date is earlier than our threshold, trigger the alert
                return measurementDate < thresholdDateTime
            }
        }

        // Default case, don't trigger alert
        return false
    }
}
