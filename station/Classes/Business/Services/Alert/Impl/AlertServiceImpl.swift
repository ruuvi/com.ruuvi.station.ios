import Foundation
import BTKit
import Humidity

class AlertServiceImpl: AlertService {

    var alertPersistence: AlertPersistence!
    var calibrationService: CalibrationService!
    weak var localNotificationsManager: LocalNotificationsManager!

    private var observations = [String: NSPointerArray]()

    func subscribe<T: AlertServiceObserver>(_ observer: T, to uuid: String) {
        let pointer = Unmanaged.passUnretained(observer).toOpaque()
        if let array = observations[uuid] {
            array.addPointer(pointer)
            array.compact()
        } else {
            let array = NSPointerArray.weakObjects()
            array.addPointer(pointer)
            observations[uuid] = array
            array.compact()
        }
    }

    func hasRegistrations(for uuid: String) -> Bool {
        var hasRegistrations = false
        AlertType.allCases.forEach { (type) in
            if isOn(type: type, for: uuid) {
                hasRegistrations = true
            }
        }
        return hasRegistrations
    }

    func isOn(type: AlertType, for uuid: String) -> Bool {
        return alert(for: uuid, of: type) != nil
    }

    func alert(for uuid: String, of type: AlertType) -> AlertType? {
        return alertPersistence.alert(for: uuid, of: type)
    }

    func register(type: AlertType, for uuid: String) {
        alertPersistence.register(type: type, for: uuid)
        postAlertDidChange(with: uuid, of: type)
    }

    func unregister(type: AlertType, for uuid: String) {
        alertPersistence.unregister(type: type, for: uuid)
        postAlertDidChange(with: uuid, of: type)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func proccess(heartbeat ruuviTag: RuuviTag) {
        var isTriggered = false
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                if case .temperature(let lower, let upper) = alert(for: ruuviTag.uuid, of: type),
                    let celsius = ruuviTag.celsius {
                    let isLower = celsius < lower
                    let isUpper = celsius > upper
                    if isLower {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager.notifyLowTemperature(for: ruuviTag.uuid, celsius: celsius)
                        }
                    } else if isUpper {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager.notifyHighTemperature(for: ruuviTag.uuid, celsius: celsius)
                        }
                    }
                    isTriggered = isTriggered || isLower || isUpper
                }
            case .relativeHumidity:
                if case .relativeHumidity(let lower, let upper) = alert(for: ruuviTag.uuid, of: type),
                    let relativeHumidity = ruuviTag.humidity {
                    let isLower = relativeHumidity < lower
                    let isUpper = relativeHumidity > upper
                    if isLower {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager
                                .notifyLowRelativeHumidity(for: ruuviTag.uuid, relativeHumidity: relativeHumidity)
                        }
                    } else if isUpper {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager
                                .notifyHighRelativeHumidity(for: ruuviTag.uuid, relativeHumidity: relativeHumidity)
                        }
                    }
                    isTriggered = isTriggered || isLower || isUpper
                }
            case .absoluteHumidity:
                if case .absoluteHumidity(let lower, let upper) = alert(for: ruuviTag.uuid, of: type),
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
                            self?.localNotificationsManager
                                .notifyLowAbsoluteHumidity(for: ruuviTag.uuid, absoluteHumidity: ah)
                        }
                    } else if isUpper {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager
                                .notifyHighAbsoluteHumidity(for: ruuviTag.uuid, absoluteHumidity: ah)
                        }
                    }

                    isTriggered = isTriggered || isLower || isUpper
                }
            case .dewPoint:
                if case .dewPoint(let lower, let upper) = alert(for: ruuviTag.uuid, of: type),
                    let rh = ruuviTag.humidity, let c = ruuviTag.celsius {
                    let ho = calibrationService.humidityOffset(for: ruuviTag.uuid).0
                    var sh = rh + ho
                    if sh > 100.0 {
                        sh = 100.0
                    }
                    let h = Humidity(c: c, rh: sh / 100.0)
                    if let Td = h.Td {
                        let isLower = Td < lower
                        let isUpper = Td > upper

                        if isLower {
                            DispatchQueue.main.async { [weak self] in
                                self?.localNotificationsManager
                                    .notifyLowDewPoint(for: ruuviTag.uuid, dewPointCelsius: Td)
                            }
                        } else if isUpper {
                            DispatchQueue.main.async { [weak self] in
                                self?.localNotificationsManager
                                    .notifyHighDewPoint(for: ruuviTag.uuid, dewPointCelsius: Td)
                            }
                        }

                        isTriggered = isTriggered || isLower || isUpper
                    }
                }
            case .pressure:
                if case .pressure(let lower, let upper) = alert(for: ruuviTag.uuid, of: type),
                    let pressure = ruuviTag.pressure {
                    let isLower = pressure < lower
                    let isUpper = pressure > upper
                    if isLower {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager
                                .notifyLowPressure(for: ruuviTag.uuid, pressure: pressure)
                        }
                    } else if isUpper {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager
                                .notifyHighPressure(for: ruuviTag.uuid, pressure: pressure)
                        }
                    }
                    isTriggered = isTriggered || isLower || isUpper
                }
            case .connection:
                //do nothing
                break
            case .movement:
                if case .movement(let last) = alert(for: ruuviTag.uuid, of: type),
                    let movementCounter = ruuviTag.movementCounter {
                    let isGreater = movementCounter > last
                    if isGreater {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager
                                .notifyDidMove(for: ruuviTag.uuid, counter: movementCounter)
                        }
                    }
                    isTriggered = isTriggered || isGreater
                }
            }
        }

        if let movementCounter = ruuviTag.movementCounter {
            setMovement(counter: movementCounter, for: ruuviTag.uuid)
        }

        if hasRegistrations(for: ruuviTag.uuid) {
            DispatchQueue.main.async { [weak self] in
                guard let sSelf = self else { return }
                if let observers = sSelf.observations[ruuviTag.uuid] {
                    for i in 0..<observers.count {
                        if let pointer = observers.pointer(at: i),
                            let observer = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
                                as? AlertServiceObserver {
                            observer.alert(service: sSelf,
                                           isTriggered: isTriggered,
                                           for: ruuviTag.uuid)
                        }
                    }
                }
            }
        }
    }

    private func postAlertDidChange(with uuid: String, of type: AlertType) {
        NotificationCenter
            .default
            .post(name: .AlertServiceAlertDidChange,
                  object: nil,
                  userInfo: [AlertServiceAlertDidChangeKey.uuid: uuid,
                             AlertServiceAlertDidChangeKey.type: type])
    }
}

// MARK: - Temperature
extension AlertServiceImpl {

    func lowerCelsius(for uuid: String) -> Double? {
        return alertPersistence.lowerCelsius(for: uuid)
    }

    func setLower(celsius: Double?, for uuid: String) {
        alertPersistence.setLower(celsius: celsius, for: uuid)
        if let l = celsius, let u = upperCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .temperature(lower: l, upper: u))
        }
    }

    func upperCelsius(for uuid: String) -> Double? {
        return alertPersistence.upperCelsius(for: uuid)
    }

    func setUpper(celsius: Double?, for uuid: String) {
        alertPersistence.setUpper(celsius: celsius, for: uuid)
        if let u = celsius, let l = lowerCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .temperature(lower: l, upper: u))
        }
    }

    func temperatureDescription(for uuid: String) -> String? {
        return alertPersistence.temperatureDescription(for: uuid)
    }

    func setTemperature(description: String?, for uuid: String) {
        alertPersistence.setTemperature(description: description, for: uuid)
        if let l = lowerCelsius(for: uuid), let u = upperCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .temperature(lower: l, upper: u))
        }
    }
}

// MARK: - Relative Humidity
extension AlertServiceImpl {
    func lowerRelativeHumidity(for uuid: String) -> Double? {
        return alertPersistence.lowerRelativeHumidity(for: uuid)
    }

    func setLower(relativeHumidity: Double?, for uuid: String) {
        alertPersistence.setLower(relativeHumidity: relativeHumidity, for: uuid)
        if let l = relativeHumidity, let u = upperRelativeHumidity(for: uuid) {
            postAlertDidChange(with: uuid, of: .relativeHumidity(lower: l, upper: u))
        }
    }

    func upperRelativeHumidity(for uuid: String) -> Double? {
        return alertPersistence.upperRelativeHumidity(for: uuid)
    }

    func setUpper(relativeHumidity: Double?, for uuid: String) {
        alertPersistence.setUpper(relativeHumidity: relativeHumidity, for: uuid)
        if let u = relativeHumidity, let l = lowerRelativeHumidity(for: uuid) {
            postAlertDidChange(with: uuid, of: .relativeHumidity(lower: l, upper: u))
        }
    }

    func relativeHumidityDescription(for uuid: String) -> String? {
        return alertPersistence.relativeHumidityDescription(for: uuid)
    }

    func setRelativeHumidity(description: String?, for uuid: String) {
        alertPersistence.setRelativeHumidity(description: description, for: uuid)
        if let l = lowerRelativeHumidity(for: uuid), let u = upperRelativeHumidity(for: uuid) {
            postAlertDidChange(with: uuid, of: .relativeHumidity(lower: l, upper: u))
        }
    }
}

// MARK: - Absoulte Humidity
extension AlertServiceImpl {
    func lowerAbsoluteHumidity(for uuid: String) -> Double? {
        return alertPersistence.lowerAbsoluteHumidity(for: uuid)
    }

    func setLower(absoluteHumidity: Double?, for uuid: String) {
        alertPersistence.setLower(absoluteHumidity: absoluteHumidity, for: uuid)
        if let l = absoluteHumidity, let u = upperAbsoluteHumidity(for: uuid) {
            postAlertDidChange(with: uuid, of: .absoluteHumidity(lower: l, upper: u))
        }
    }

    func upperAbsoluteHumidity(for uuid: String) -> Double? {
        return alertPersistence.upperAbsoluteHumidity(for: uuid)
    }

    func setUpper(absoluteHumidity: Double?, for uuid: String) {
        alertPersistence.setUpper(absoluteHumidity: absoluteHumidity, for: uuid)
        if let u = absoluteHumidity, let l = lowerAbsoluteHumidity(for: uuid) {
            postAlertDidChange(with: uuid, of: .absoluteHumidity(lower: l, upper: u))
        }
    }

    func absoluteHumidityDescription(for uuid: String) -> String? {
        return alertPersistence.absoluteHumidityDescription(for: uuid)
    }

    func setAbsoluteHumidity(description: String?, for uuid: String) {
        alertPersistence.setAbsoluteHumidity(description: description, for: uuid)
        if let l = lowerAbsoluteHumidity(for: uuid), let u = upperAbsoluteHumidity(for: uuid) {
            postAlertDidChange(with: uuid, of: .absoluteHumidity(lower: l, upper: u))
        }
    }
}

// MARK: - Dew Point
extension AlertServiceImpl {
    func lowerDewPointCelsius(for uuid: String) -> Double? {
        return alertPersistence.lowerDewPointCelsius(for: uuid)
    }

    func setLowerDewPoint(celsius: Double?, for uuid: String) {
        alertPersistence.setLowerDewPoint(celsius: celsius, for: uuid)
        if let l = celsius, let u = upperDewPointCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .dewPoint(lower: l, upper: u))
        }
    }

    func upperDewPointCelsius(for uuid: String) -> Double? {
        return alertPersistence.upperDewPointCelsius(for: uuid)
    }

    func setUpperDewPoint(celsius: Double?, for uuid: String) {
        alertPersistence.setUpperDewPoint(celsius: celsius, for: uuid)
        if let u = celsius, let l = lowerDewPointCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .dewPoint(lower: l, upper: u))
        }
    }

    func dewPointDescription(for uuid: String) -> String? {
        return alertPersistence.dewPointDescription(for: uuid)
    }

    func setDewPoint(description: String?, for uuid: String) {
        alertPersistence.setDewPoint(description: description, for: uuid)
        if let l = lowerDewPointCelsius(for: uuid), let u = upperDewPointCelsius(for: uuid) {
            postAlertDidChange(with: uuid, of: .dewPoint(lower: l, upper: u))
        }
    }
}

// MARK: - Pressure
extension AlertServiceImpl {
    func lowerPressure(for uuid: String) -> Double? {
        return alertPersistence.lowerPressure(for: uuid)
    }

    func setLower(pressure: Double?, for uuid: String) {
        alertPersistence.setLower(pressure: pressure, for: uuid)
        if let l = pressure, let u = upperPressure(for: uuid) {
            postAlertDidChange(with: uuid, of: .pressure(lower: l, upper: u))
        }
    }

    func upperPressure(for uuid: String) -> Double? {
        return alertPersistence.upperPressure(for: uuid)
    }

    func setUpper(pressure: Double?, for uuid: String) {
        alertPersistence.setUpper(pressure: pressure, for: uuid)
        if let u = pressure, let l = lowerPressure(for: uuid) {
            postAlertDidChange(with: uuid, of: .pressure(lower: l, upper: u))
        }
    }

    func pressureDescription(for uuid: String) -> String? {
        return alertPersistence.pressureDescription(for: uuid)
    }

    func setPressure(description: String?, for uuid: String) {
        alertPersistence.setPressure(description: description, for: uuid)
        if let l = lowerPressure(for: uuid), let u = upperPressure(for: uuid) {
            postAlertDidChange(with: uuid, of: .pressure(lower: l, upper: u))
        }
    }
}

// MARK: - Movement
extension AlertServiceImpl {
    func movementCounter(for uuid: String) -> Int? {
        return alertPersistence.movementCounter(for: uuid)
    }

    func setMovement(counter: Int?, for uuid: String) {
        alertPersistence.setMovement(counter: counter, for: uuid)
        if let c = counter {
            postAlertDidChange(with: uuid, of: .movement(last: c))
        }
    }
}
