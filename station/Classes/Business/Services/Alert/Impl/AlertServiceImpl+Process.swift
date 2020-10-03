import Foundation
import BTKit
import Humidity

// MARK: - Process Physical Sensors
extension AlertServiceImpl {

    func process(heartbeat ruuviTag: RuuviTagSensorRecord) {
        var isTriggered = false
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                isTriggered = isTriggered
                    || process(temperature: ruuviTag.temperature,
                               alertType: type,
                               identifier: ruuviTag.ruuviTagId.luid)
            case .humidity:
                isTriggered = isTriggered
                    || process(humidity: ruuviTag.humidity,
                               temperature: ruuviTag.temperature,
                               alertType: type,
                               identifier: ruuviTag.ruuviTagId.luid)
            case .dewPoint:
                isTriggered = isTriggered
                    || processDewPoint(humidity: ruuviTag.humidity,
                                       temperature: ruuviTag.temperature,
                                       alertType: type, identifier: ruuviTag.ruuviTagId.luid)
            case .pressure:
                isTriggered = isTriggered
                    || process(pressure: ruuviTag.pressure,
                               alertType: type,
                               identifier: ruuviTag.ruuviTagId.luid)
            case .movement:
                isTriggered = isTriggered || process(movement: type, ruuviTag: ruuviTag)
            case .connection:
                //do nothing, see RuuviTagHeartbeatDaemon
                break
            }
        }

        let uuid = ruuviTag.ruuviTagId
        if let movementCounter = ruuviTag.movementCounter {
            setMovement(counter: movementCounter, for: uuid)
        }

        if hasRegistrations(for: uuid) {
            notify(uuid: uuid, isTriggered: isTriggered)
        }
    }
}

// MARK: - Process Virtual Sensors
extension AlertServiceImpl {

    func process(data: WPSData, for uuid: String) {
        var isTriggered = false
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                isTriggered = process(temperature: data.temperature,
                                      alertType: type,
                                      identifier: uuid.luid)
                    || isTriggered
            case .humidity:
                isTriggered = process(humidity: data.humidity,
                                      temperature: data.temperature,
                                      alertType: type,
                                      identifier: uuid.luid)
                    || isTriggered
            case .dewPoint:
                isTriggered = processDewPoint(humidity: data.humidity,
                                              temperature: data.temperature,
                                              alertType: type,
                                              identifier: uuid.luid)
                    || isTriggered
            case .pressure:
                isTriggered = process(pressure: data.pressure,
                                      alertType: type,
                                      identifier: uuid.luid)
            default:
                break
            }
        }

        if hasRegistrations(for: uuid) {
            notify(uuid: uuid, isTriggered: isTriggered)
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

        if hasRegistrations(for: identifier.value) {
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
    private func process(temperature: Temperature?,
                         alertType: AlertType,
                         identifier: Identifier) -> Bool {
        if case .temperature(let lower, let upper) = alert(for: identifier.value, of: alertType),
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

    private func process(humidity: Humidity?,
                         temperature: Temperature?,
                         alertType: AlertType,
                         identifier: Identifier) -> Bool {
        let ho = calibrationService.humidityOffset(for: identifier).0
        if case .humidity(let lower, let upper) = alert(for: identifier.value, of: alertType),
           let rh = humidity,
           let sh = rh.offseted(by: ho, temperature: temperature) {
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

    private func processDewPoint(humidity: Humidity?,
                                 temperature: Temperature?,
                                 alertType: AlertType,
                                 identifier: Identifier) -> Bool {
        let ho = calibrationService.humidityOffset(for: identifier).0
        if case .dewPoint(let lower, let upper) = alert(for: identifier.value, of: alertType),
           let t = temperature,
           let rh = humidity?.converted(to: .relative(temperature: t)),
            let sh = rh.offseted(by: ho, temperature: t),
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

    private func process(pressure: Pressure?,
                         alertType: AlertType,
                         identifier: Identifier) -> Bool {
        if case .pressure(let lower, let upper) = alert(for: identifier.value, of: alertType),
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

    private func process(movement: AlertType, ruuviTag: RuuviTagSensorRecord) -> Bool {
        if case .movement(let last) = alert(for: ruuviTag.ruuviTagId, of: movement),
            let movementCounter = ruuviTag.movementCounter {
            let isGreater = movementCounter > last
            if isGreater {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager
                        .notifyDidMove(for: ruuviTag.ruuviTagId, counter: movementCounter)
                }
            }
            return isGreater
        } else {
            return false
        }
    }
}
