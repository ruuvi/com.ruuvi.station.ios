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
                isTriggered = isTriggered || process(temperature: type, ruuviTag: ruuviTag)
            case .humidity:
                isTriggered = isTriggered || process(humidity: type, ruuviTag: ruuviTag)
            case .dewPoint:
                isTriggered = isTriggered || process(dewPoint: type, ruuviTag: ruuviTag)
            case .pressure:
                isTriggered = isTriggered || process(pressure: type, ruuviTag: ruuviTag)
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

    private func process(temperature: AlertType, ruuviTag: RuuviTagSensorRecord) -> Bool {
        if case .temperature(let lower, let upper) = alert(for: ruuviTag.ruuviTagId, of: temperature),
           let l = Temperature(lower),
           let u = Temperature(upper),
           let t = ruuviTag.temperature {
            let isLower = t < l
            let isUpper = t > u
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .temperature, for: ruuviTag.ruuviTagId)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .temperature, for: ruuviTag.ruuviTagId)
                }
            }
            return isLower || isUpper
        } else {
             return false
        }
    }

    private func process(humidity: AlertType, ruuviTag: RuuviTagSensorRecord) -> Bool {
         let ho = calibrationService.humidityOffset(for: ruuviTag.ruuviTagId.luid).0
        if case .humidity(let lower, let upper) = alert(for: ruuviTag.ruuviTagId, of: humidity),
           let rh = ruuviTag.humidity,
           let sh = rh.offseted(by: ho, temperature: ruuviTag.temperature) {
            let isLower = sh < lower
            let isUpper = sh > upper
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .humidity, for: ruuviTag.ruuviTagId)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .humidity, for: ruuviTag.ruuviTagId)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(dewPoint: AlertType, ruuviTag: RuuviTagSensorRecord) -> Bool {
        let ho = calibrationService.humidityOffset(for: ruuviTag.ruuviTagId.luid).0
        if case .dewPoint(let lower, let upper) = alert(for: ruuviTag.ruuviTagId, of: dewPoint),
           let rh = ruuviTag.humidity,
           let t = ruuviTag.temperature,
            let sh = rh.offseted(by: ho, temperature: ruuviTag.temperature),
            let dp = try? sh.dewPoint(temperature: t) {
            let isLower = dp < Temperature(value: lower, unit: .celsius)
            let isUpper = dp > Temperature(value: upper, unit: .celsius)
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .dewPoint, for: ruuviTag.ruuviTagId)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .dewPoint, for: ruuviTag.ruuviTagId)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(pressure: AlertType, ruuviTag: RuuviTagSensorRecord) -> Bool {
        if case .pressure(let lower, let upper) = alert(for: ruuviTag.ruuviTagId, of: pressure),
           let l = Pressure(lower),
           let u = Pressure(upper),
           let pressure = ruuviTag.pressure {
            let isLower = pressure < l
            let isUpper = pressure > u
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .pressure, for: ruuviTag.ruuviTagId)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .pressure, for: ruuviTag.ruuviTagId)
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

// MARK: - Process Virtual Sensors
extension AlertServiceImpl {

    func process(data: WPSData, for uuid: String) {
        var isTriggered = false
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                isTriggered = process(temperature: type, uuid: uuid, data: data) || isTriggered
            case .humidity:
                isTriggered = process(humidity: type, uuid: uuid, data: data) || isTriggered
            case .pressure:
                isTriggered = process(pressure: type, uuid: uuid, data: data) || isTriggered
            default:
                break
            }
        }

        if hasRegistrations(for: uuid) {
            notify(uuid: uuid, isTriggered: isTriggered)
        }
    }

    private func process(temperature: AlertType, uuid: String, data: WPSData) -> Bool {
        if case .temperature(let lower, let upper) = alert(for: uuid, of: temperature),
            let celsius = data.celsius {
            let isLower = celsius < lower
            let isUpper = celsius > upper
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .temperature, for: uuid)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .temperature, for: uuid)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(humidity: AlertType, uuid: String, data: WPSData) -> Bool {
        if case .humidity(let lower, let upper) = alert(for: uuid, of: humidity),
           let humidity = data.humidity {
            let isLower = humidity < lower
            let isUpper = humidity > upper
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .humidity, for: uuid)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .humidity, for: uuid)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(pressure: AlertType, uuid: String, data: WPSData) -> Bool {
        if case .pressure(let lower, let upper) = alert(for: uuid, of: pressure),
            let pressure = data.hPa {
            let isLower = pressure < lower
            let isUpper = pressure > upper
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .pressure, for: uuid)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .pressure, for: uuid)
                }
            }
            return isLower || isUpper
        } else {
            return false
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
