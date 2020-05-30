import Foundation
import BTKit
import Humidity

// MARK: - Process Physical Sensors
extension AlertServiceImpl {

    func process(heartbeat ruuviTag: RuuviTagProtocol) {
        var isTriggered = false
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                isTriggered = isTriggered
                    || process(temperature: ruuviTag.celsius,
                               alertType: type,
                               identifier: ruuviTag.uuid.luid)
            case .relativeHumidity:
                isTriggered = isTriggered
                    || process(relativeHumidity: ruuviTag.relativeHumidity,
                               alertType: type,
                               identifier: ruuviTag.uuid.luid)
            case .absoluteHumidity:
                isTriggered = isTriggered
                    || processAbsoluteHumidity(relativeHumidity: ruuviTag.relativeHumidity,
                                               celsius: ruuviTag.celsius,
                                               alertType: type, identifier: ruuviTag.uuid.luid)
            case .dewPoint:
                isTriggered = isTriggered
                    || processDewPoint(relativeHumidity: ruuviTag.relativeHumidity,
                                       celsius: ruuviTag.celsius,
                                       alertType: type,
                                       identifier: ruuviTag.uuid.luid)
            case .pressure:
                isTriggered = isTriggered
                    || process(pressure: ruuviTag.hectopascals,
                               alertType: type,
                               identifier: ruuviTag.uuid.luid)
            case .movement:
                isTriggered = isTriggered || process(movement: type, ruuviTag: ruuviTag)
            case .connection:
                //do nothing, see RuuviTagHeartbeatDaemon
                break
            }
        }
        
        let uuid = ruuviTag.uuid
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
                isTriggered = process(temperature: data.celsius,
                                      alertType: type,
                                      identifier: uuid.luid)
                    || isTriggered
            case .relativeHumidity:
                isTriggered = process(relativeHumidity: data.humidity,
                                      alertType: type,
                                      identifier: uuid.luid)
                    || isTriggered
            case .absoluteHumidity:
                isTriggered = processAbsoluteHumidity(relativeHumidity: data.humidity,
                                                      celsius: data.celsius,
                                                      alertType: type,
                                                      identifier: uuid.luid)
                    || isTriggered
            case .dewPoint:
                isTriggered = processDewPoint(relativeHumidity: data.humidity,
                                              celsius: data.celsius,
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
                isTriggered = process(temperature: record.temperature?.converted(to: .celsius).value,
                                      alertType: type,
                                      identifier: identifier)
                    || isTriggered
            case .relativeHumidity:
                isTriggered = process(relativeHumidity: record.humidity?.rh,
                                      alertType: type,
                                      identifier: identifier)
                    || isTriggered
            case .absoluteHumidity:
                isTriggered = processAbsoluteHumidity(relativeHumidity: record.humidity?.rh,
                                                      celsius: record.temperature?.converted(to: .celsius).value,
                                                      alertType: type,
                                                      identifier: identifier)
                    || isTriggered
            case .dewPoint:
                isTriggered = processDewPoint(relativeHumidity: record.humidity?.rh,
                                              celsius: record.temperature?.converted(to: .celsius).value,
                                              alertType: type,
                                              identifier: identifier)
                    || isTriggered
            case .pressure:
                isTriggered = process(pressure: record.pressure?.converted(to: .hectopascals).value,
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
    private func process(temperature: Double?,
                         alertType: AlertType,
                         identifier: Identifier) -> Bool {
        if case .temperature(let lower, let upper) = alert(for: identifier.value, of: alertType),
            let celsius = temperature {
            let isLower = celsius < lower
            let isUpper = celsius > upper
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

    private func process(relativeHumidity: Double?,
                         alertType: AlertType,
                         identifier: Identifier) -> Bool {
        if case .relativeHumidity(let lower, let upper) = alert(for: identifier.value, of: alertType),
            let rh = relativeHumidity {
            let ho = calibrationService.humidityOffset(for: identifier).0
            var sh = rh + ho
            if sh > 100.0 {
                sh = 100.0
            }
            let isLower = sh < lower
            let isUpper = sh > upper
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .relativeHumidity, for: identifier.value)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .relativeHumidity, for: identifier.value)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func processAbsoluteHumidity(relativeHumidity: Double?,
                                         celsius: Double?,
                                         alertType: AlertType,
                                         identifier: Identifier) -> Bool {
        if case .absoluteHumidity(let lower, let upper) = alert(for: identifier.value, of: alertType),
            let rh = relativeHumidity,
            let c = celsius {
            let ho = calibrationService.humidityOffset(for: identifier).0
            var sh = rh + ho
            if sh > 100.0 {
                sh = 100.0
            }
            let h = Humidity(c: c, rh: sh / 100.0)
            let ah = h.ah
            
            let isLower = ah < lower
            let isUpper = ah > upper
            
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .absoluteHumidity, for: identifier.value)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .absoluteHumidity, for: identifier.value)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func processDewPoint(relativeHumidity: Double?,
                                 celsius: Double?,
                                 alertType: AlertType,
                                 identifier: Identifier) -> Bool {
        if case .dewPoint(let lower, let upper) = alert(for: identifier.value, of: alertType),
            let rh = relativeHumidity,
            let c = celsius {
            let ho = calibrationService.humidityOffset(for: identifier).0
            var sh = rh + ho
            if sh > 100.0 {
                sh = 100.0
            }
            let h = Humidity(c: c, rh: sh / 100.0)
            if let hTd = h.Td {
                let isLower = hTd < lower
                let isUpper = hTd > upper
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
        } else {
            return false
        }
    }

    private func process(pressure: Double?,
                         alertType: AlertType,
                         identifier: Identifier) -> Bool {
        if case .pressure(let lower, let upper) = alert(for: identifier.value, of: alertType),
            let pressure = pressure {
            let isLower = pressure < lower
            let isUpper = pressure > upper
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

    private func process(movement: AlertType, ruuviTag: RuuviTagProtocol) -> Bool {
        if case .movement(let last) = alert(for: ruuviTag.uuid, of: movement),
            let movementCounter = ruuviTag.movementCounter {
            let isGreater = movementCounter > last
            if isGreater {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager
                        .notifyDidMove(for: ruuviTag.uuid, counter: movementCounter)
                }
            }
            return isGreater
        } else {
            return false
        }
    }
}
