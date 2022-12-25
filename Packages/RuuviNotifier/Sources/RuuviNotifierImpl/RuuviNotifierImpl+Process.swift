import Foundation
import RuuviOntology
import RuuviVirtual
import RuuviNotifier

// MARK: - Process Physical Sensors
extension RuuviNotifierImpl {

    public func process(record record: RuuviTagSensorRecord, trigger: Bool) {
        guard let luid = record.luid,
                ruuviAlertService.hasRegistrations(for: record) else {
            return
        }
        var isTriggered = false
        AlertType.allCases.forEach { (type) in
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
            case .movement:
                let isMovement = process(movement: type,
                                         record: record,
                                         trigger: trigger)
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

// MARK: - Process Virtual Sensors
extension RuuviNotifierImpl {
    public func process(data: VirtualData, for sensor: VirtualSensor) {
        var isTriggered = false
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                isTriggered = process(temperature: data.temperature,
                                      alertType: type,
                                      identifier: sensor.id.luid)
                    || isTriggered
            case .relativeHumidity:
                let isRelativeHumidity = process(
                    relativeHumidity: data.humidity,
                    temperature: data.temperature,
                    alertType: type,
                    identifier: sensor.id.luid
                )
                isTriggered = isTriggered || isRelativeHumidity
                    || isTriggered
            case .pressure:
                isTriggered = process(pressure: data.pressure,
                                      alertType: type,
                                      identifier: sensor.id.luid)
            default:
                break
            }
        }

        if ruuviAlertService.hasRegistrations(for: sensor) {
            notify(uuid: sensor.id, isTriggered: isTriggered)
        }
    }

}
// MARK: - Process Network Sensors
extension RuuviNotifierImpl {
    public func processNetwork(record: RuuviTagSensorRecord,
                               trigger: Bool,
                               for identifier: MACIdentifier) {
        guard ruuviAlertService.hasRegistrations(for: record) else {
            return
        }

        var isTriggered = false
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                let isTemperature = process(temperature: record.temperature,
                                      alertType: type,
                                      identifier: identifier,
                                      trigger: trigger)
                isTriggered = isTriggered || isTemperature
                notify(alertType: type,
                       uuid: identifier.value,
                       isTriggered: isTemperature)
            case .relativeHumidity:
                let isRelativeHumidity = process(
                    relativeHumidity: record.humidity,
                    temperature: record.temperature,
                    alertType: type,
                    identifier: identifier,
                    trigger: trigger
                )
                isTriggered = isTriggered || isRelativeHumidity
                notify(alertType: type,
                       uuid: identifier.value,
                       isTriggered: isRelativeHumidity)
            case .pressure:
                let isPressure = process(pressure: record.pressure,
                                      alertType: type,
                                      identifier: identifier,
                                      trigger: trigger)
                isTriggered = isTriggered || isPressure
                notify(alertType: type,
                       uuid: identifier.value,
                       isTriggered: isPressure)
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
                for i in 0..<observers.count {
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
                for i in 0..<observers.count {
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
        guard let identifier = identifier else { return false }
        if case .temperature(let lower, let upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
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
        guard let identifier = identifier else { return false }
        if case .relativeHumidity(let lower, let upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
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
        guard let identifier = identifier else { return false }
        if case .pressure(let lower, let upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
           let l = Pressure(lower),
           let u = Pressure(upper),
           let pressure = pressure {
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
        movement: AlertType,
        record: RuuviTagSensorRecord,
        trigger: Bool = true
    ) -> Bool {
        guard let luid = record.luid else { return false }
        if case .movement(let last) = ruuviAlertService.alert(for: luid.value, of: movement),
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
}
