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
                isTriggered = isTriggered || process(temperature: type, ruuviTag: ruuviTag)
            case .relativeHumidity:
                isTriggered = isTriggered || process(relativeHumidity: type, ruuviTag: ruuviTag)
            case .absoluteHumidity:
                isTriggered = isTriggered || process(absoluteHumidity: type, ruuviTag: ruuviTag)
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

        let uuid = ruuviTag.uuid
        if let movementCounter = ruuviTag.movementCounter {
            setMovement(counter: movementCounter, for: uuid)
        }

        if hasRegistrations(for: uuid) {
            notify(uuid: uuid, isTriggered: isTriggered)
        }
    }

    private func process(temperature: AlertType, ruuviTag: RuuviTagProtocol) -> Bool {
        if case .temperature(let lower, let upper) = alert(for: ruuviTag.uuid, of: temperature),
            let celsius = ruuviTag.celsius {
            let isLower = celsius < lower
            let isUpper = celsius > upper
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .temperature, for: ruuviTag.uuid)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .temperature, for: ruuviTag.uuid)
                }
            }
            return isLower || isUpper
        } else {
             return false
        }
    }

    private func process(relativeHumidity: AlertType, ruuviTag: RuuviTagProtocol) -> Bool {
        if case .relativeHumidity(let lower, let upper) = alert(for: ruuviTag.uuid, of: relativeHumidity),
            let rh = ruuviTag.humidity {
            let ho = calibrationService.humidityOffset(for: ruuviTag.uuid).0
            var sh = rh + ho
            if sh > 100.0 {
                sh = 100.0
            }
            let isLower = sh < lower
            let isUpper = sh > upper
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .relativeHumidity, for: ruuviTag.uuid)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .relativeHumidity, for: ruuviTag.uuid)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(absoluteHumidity: AlertType, ruuviTag: RuuviTagProtocol) -> Bool {
        if case .absoluteHumidity(let lower, let upper) = alert(for: ruuviTag.uuid, of: absoluteHumidity),
            let rh = ruuviTag.humidity,
            let c = ruuviTag.celsius {
            let ho = calibrationService.humidityOffset(for: ruuviTag.uuid).0
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
                    self?.localNotificationsManager.notify(.low, .absoluteHumidity, for: ruuviTag.uuid)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .absoluteHumidity, for: ruuviTag.uuid)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(dewPoint: AlertType, ruuviTag: RuuviTagProtocol) -> Bool {
        if case .dewPoint(let lower, let upper) = alert(for: ruuviTag.uuid, of: dewPoint),
            let rh = ruuviTag.humidity, let c = ruuviTag.celsius {
            let ho = calibrationService.humidityOffset(for: ruuviTag.uuid).0
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
                        self?.localNotificationsManager.notify(.low, .dewPoint, for: ruuviTag.uuid)
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        self?.localNotificationsManager.notify(.high, .dewPoint, for: ruuviTag.uuid)
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

    private func process(pressure: AlertType, ruuviTag: RuuviTagProtocol) -> Bool {
        if case .pressure(let lower, let upper) = alert(for: ruuviTag.uuid, of: pressure),
            let pressure = ruuviTag.pressure {
            let isLower = pressure < lower
            let isUpper = pressure > upper
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .pressure, for: ruuviTag.uuid)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .pressure, for: ruuviTag.uuid)
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

// MARK: - Process Virtual Sensors
extension AlertServiceImpl {

    func process(data: WPSData, for uuid: String) {
        var isTriggered = false
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                isTriggered = isTriggered || process(temperature: type, uuid: uuid, data: data)
            case .relativeHumidity:
                isTriggered = isTriggered || process(relativeHumidity: type, uuid: uuid, data: data)
            case .absoluteHumidity:
                isTriggered = isTriggered || process(absoluteHumidity: type, uuid: uuid, data: data)
            case .dewPoint:
                isTriggered = isTriggered || process(dewPoint: type, uuid: uuid, data: data)
            case .pressure:
                isTriggered = isTriggered || process(pressure: type, uuid: uuid, data: data)
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

    private func process(relativeHumidity: AlertType, uuid: String, data: WPSData) -> Bool {
        if case .relativeHumidity(let lower, let upper) = alert(for: uuid, of: relativeHumidity),
            let relativeHumidity = data.humidity {
            let isLower = relativeHumidity < lower
            let isUpper = relativeHumidity > upper
            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .relativeHumidity, for: uuid)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .relativeHumidity, for: uuid)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(absoluteHumidity: AlertType, uuid: String, data: WPSData) -> Bool {
        if case .absoluteHumidity(let lower, let upper) = alert(for: uuid, of: absoluteHumidity),
            let rh = data.humidity,
            let c = data.celsius {
            let h = Humidity(c: c, rh: rh / 100.0)
            let ah = h.ah

            let isLower = ah < lower
            let isUpper = ah > upper

            if isLower {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.low, .absoluteHumidity, for: uuid)
                }
            } else if isUpper {
                DispatchQueue.main.async { [weak self] in
                    self?.localNotificationsManager.notify(.high, .absoluteHumidity, for: uuid)
                }
            }
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func process(dewPoint: AlertType, uuid: String, data: WPSData) -> Bool {
        if case .dewPoint(let lower, let upper) = alert(for: uuid, of: dewPoint),
            let rh = data.humidity, let c = data.celsius {
            let h = Humidity(c: c, rh: rh / 100.0)
            if let hTd = h.Td {
                let isLower = hTd < lower
                let isUpper = hTd > upper

                if isLower {
                    DispatchQueue.main.async { [weak self] in
                        self?.localNotificationsManager.notify(.low, .dewPoint, for: uuid)
                    }
                } else if isUpper {
                    DispatchQueue.main.async { [weak self] in
                        self?.localNotificationsManager.notify(.high, .dewPoint, for: uuid)
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

    private func process(pressure: AlertType, uuid: String, data: WPSData) -> Bool {
        if case .pressure(let lower, let upper) = alert(for: uuid, of: pressure),
            let pressure = data.pressure {
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
