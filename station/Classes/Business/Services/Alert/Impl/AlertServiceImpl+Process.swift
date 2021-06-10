import Foundation
import BTKit
import Humidity
import RuuviOntology

// MARK: - Process Physical Sensors
extension AlertServiceImpl {
    func process(heartbeat record: RuuviTagSensorRecord) {
        var isTriggered = false
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                let isTemperature = process(
                    temperature: record.temperature,
                    alertType: type,
                    identifier: record.luid
                )
                isTriggered = isTriggered || isTemperature
            case .humidity:
                let isHumidity = process(
                    humidity: record.humidity,
                    temperature: record.temperature,
                    alertType: type,
                    identifier: record.luid
                )
                isTriggered = isTriggered || isHumidity
            case .dewPoint:
                let isDewPoint = processDewPoint(
                    humidity: record.humidity,
                    temperature: record.temperature,
                    alertType: type,
                    identifier: record.luid
                )
                isTriggered = isTriggered || isDewPoint
            case .pressure:
                let isPressure = process(
                    pressure: record.pressure,
                    alertType: type,
                    identifier: record.luid
                )
                isTriggered = isTriggered || isPressure
            case .movement:
                let isMovement = process(movement: type, record: record)
                isTriggered = isTriggered || isMovement
            case .connection:
                // do nothing, see RuuviTagHeartbeatDaemon
                break
            }
        }

        if let movementCounter = record.movementCounter {
            ruuviAlertService.setMovement(counter: movementCounter, for: record)
        }

        if ruuviAlertService.hasRegistrations(for: record) {
            notify(uuid: record.id, isTriggered: isTriggered)
        }
    }
}

// MARK: - Process Virtual Sensors
extension AlertServiceImpl {
    func process(data: WPSData, for sensor: VirtualSensor) {
        var isTriggered = false
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                isTriggered = process(temperature: data.temperature,
                                      alertType: type,
                                      identifier: sensor.id.luid)
                    || isTriggered
            case .humidity:
                isTriggered = process(humidity: data.humidity,
                                      temperature: data.temperature,
                                      alertType: type,
                                      identifier: sensor.id.luid)
                    || isTriggered
            case .dewPoint:
                isTriggered = processDewPoint(humidity: data.humidity,
                                              temperature: data.temperature,
                                              alertType: type,
                                              identifier: sensor.id.luid)
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
extension AlertServiceImpl {
    func processNetwork(record: RuuviTagSensorRecord, for identifier: MACIdentifier) {
        var isTriggered = false
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                isTriggered = process(temperature: record.temperature,
                                      alertType: type,
                                      identifier: identifier)
                    || isTriggered
            case .humidity:
                isTriggered = process(humidity: record.humidity,
                                      temperature: record.temperature,
                                      alertType: type,
                                      identifier: identifier)
                    || isTriggered
            case .dewPoint:
                isTriggered = processDewPoint(humidity: record.humidity,
                                              temperature: record.temperature,
                                              alertType: type,
                                              identifier: identifier)
                    || isTriggered
            case .pressure:
                isTriggered = process(pressure: record.pressure,
                                      alertType: type,
                                      identifier: identifier)
                    || isTriggered
            default:
                break
            }
        }

        if ruuviAlertService.hasRegistrations(for: record) {
            notify(uuid: identifier.value, isTriggered: isTriggered)
        }
    }
}
// MARK: - Notify
extension AlertServiceImpl {
    private func notify(uuid: String, isTriggered: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            if let observers = sSelf.observations[uuid] {
                for i in 0..<observers.count {
                    if let pointer = observers.pointer(at: i),
                        let observer = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
                            as? AlertServiceObserver {
                        observer.alert(service: sSelf,
                                       isTriggered: isTriggered,
                                       for: uuid)
                    }
                }
            }
        }
    }
}
// MARK: - Private
extension AlertServiceImpl {
    private func process(
        temperature: Temperature?,
        alertType: AlertType,
        identifier: Identifier?
    ) -> Bool {
        guard let identifier = identifier else { return false }
        if case .temperature(let lower, let upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
           let l = Temperature(lower),
           let u = Temperature(upper),
           let t = temperature {
            let isLower = t < l
            let isUpper = t > u
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .temperature, for: identifier.value)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .temperature, for: identifier.value)
                }
            }
            return isLower || isUpper
        } else {
             return false
        }
    }

    private func process(
        humidity: Humidity?,
        temperature: Temperature?,
        alertType: AlertType,
        identifier: Identifier?
    ) -> Bool {
        guard let identifier = identifier else { return false }
        if case .humidity(let lower, let upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
           let rh = humidity,
           let sh = Humidity(relative: rh.value, temperature: temperature) {
            let isLower = sh < lower
            let isUpper = sh > upper
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .humidity, for: identifier.value)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .humidity, for: identifier.value)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func processDewPoint(
        humidity: Humidity?,
        temperature: Temperature?,
        alertType: AlertType,
        identifier: Identifier?
    ) -> Bool {
        guard let identifier = identifier else { return false }
        if case .dewPoint(let lower, let upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
           let t = temperature,
           let rh = humidity,
           let sh = Humidity(relative: rh.value, temperature: t),
            let dp = try? sh.dewPoint(temperature: t) {
            let isLower = dp < Temperature(value: lower, unit: .celsius)
            let isUpper = dp > Temperature(value: upper, unit: .celsius)
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .dewPoint, for: identifier.value)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .dewPoint, for: identifier.value)
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
        identifier: Identifier?
    ) -> Bool {
        guard let identifier = identifier else { return false }
        if case .pressure(let lower, let upper) = ruuviAlertService.alert(for: identifier.value, of: alertType),
           let l = Pressure(lower),
           let u = Pressure(upper),
           let pressure = pressure {
            let isLower = pressure < l
            let isUpper = pressure > u
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .pressure, for: identifier.value)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .pressure, for: identifier.value)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(
        movement: AlertType,
        record: RuuviTagSensorRecord
    ) -> Bool {
        if case .movement(let last) = ruuviAlertService.alert(for: record.id, of: movement),
            let movementCounter = record.movementCounter {
            let isGreater = movementCounter > last
            if isGreater {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager
                        .notifyDidMove(for: record.id, counter: movementCounter)
                }
            }
            return isGreater
        } else {
            return false
        }
    }
}
