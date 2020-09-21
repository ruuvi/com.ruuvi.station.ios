import Foundation
import BTKit

class AlertServiceImpl: AlertService {

    var alertPersistence: AlertPersistence!
    var calibrationService: CalibrationService!
    var measurementService: MeasurementsService!
    weak var localNotificationsManager: LocalNotificationsManager!

    var observations = [String: NSPointerArray]()

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
        return AlertType.allCases.contains(where: { isOn(type: $0, for: uuid) })
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

// MARK: - Absolute Humidity
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

// MARK: - Connection
extension AlertServiceImpl {
    func connectionDescription(for uuid: String) -> String? {
        return alertPersistence.connectionDescription(for: uuid)
    }

    func setConnection(description: String?, for uuid: String) {
        alertPersistence.setConnection(description: description, for: uuid)
        postAlertDidChange(with: uuid, of: .connection)
    }
}

// MARK: - Movement
extension AlertServiceImpl {
    func movementCounter(for uuid: String) -> Int? {
        return alertPersistence.movementCounter(for: uuid)
    }

    func setMovement(counter: Int?, for uuid: String) {
        alertPersistence.setMovement(counter: counter, for: uuid)
        // no need to post an update, this is not user initiated action
    }

    func movementDescription(for uuid: String) -> String? {
        return alertPersistence.movementDescription(for: uuid)
    }

    func setMovement(description: String?, for uuid: String) {
        alertPersistence.setMovement(description: description, for: uuid)
        if let c = movementCounter(for: uuid) {
            postAlertDidChange(with: uuid, of: .movement(last: c))
        }
    }
}
