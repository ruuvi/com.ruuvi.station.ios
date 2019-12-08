import Foundation
import BTKit

class AlertServiceImpl: AlertService {

    var alertPersistence: AlertPersistence!
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
        postAlertDidChange(with: uuid)
    }

    func unregister(type: AlertType, for uuid: String) {
        alertPersistence.unregister(type: type, for: uuid)
        postAlertDidChange(with: uuid)
    }

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
                if case .relativeHumidity(let lower, let upper) = alert(for: ruuviTag.uuid, of: type), let relativeHumidity = ruuviTag.humidity {
                    let isLower = relativeHumidity < lower
                    let isUpper = relativeHumidity > upper
                    if isLower {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager.notifyLowRelativeHumidity(for: ruuviTag.uuid, relativeHumidity: relativeHumidity)
                        }
                    } else if isUpper {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager.notifyHighRelativeHumidity(for: ruuviTag.uuid, relativeHumidity: relativeHumidity)
                        }
                    }
                    isTriggered = isTriggered || isLower || isUpper
                }
            }
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

    private func postAlertDidChange(with uuid: String) {
        NotificationCenter
            .default
            .post(name: .AlertServiceAlertDidChange,
                  object: nil,
                  userInfo: [AlertServiceAlertDidChangeKey.uuid: uuid])
    }
}

// MARK: - Temperature
extension AlertServiceImpl {

    func lowerCelsius(for uuid: String) -> Double? {
        return alertPersistence.lowerCelsius(for: uuid)
    }

    func setLower(celsius: Double?, for uuid: String) {
        alertPersistence.setLower(celsius: celsius, for: uuid)
        postAlertDidChange(with: uuid)
    }

    func upperCelsius(for uuid: String) -> Double? {
        return alertPersistence.upperCelsius(for: uuid)
    }

    func setUpper(celsius: Double?, for uuid: String) {
        alertPersistence.setUpper(celsius: celsius, for: uuid)
        postAlertDidChange(with: uuid)
    }

    func temperatureDescription(for uuid: String) -> String? {
        return alertPersistence.temperatureDescription(for: uuid)
    }

    func setTemperature(description: String?, for uuid: String) {
        alertPersistence.setTemperature(description: description, for: uuid)
        postAlertDidChange(with: uuid)
    }
}

// MARK: - Relative Humidity
extension AlertServiceImpl {
    func lowerRelativeHumidity(for uuid: String) -> Double? {
        return alertPersistence.lowerRelativeHumidity(for: uuid)
    }

    func setLower(relativeHumidity: Double?, for uuid: String) {
        alertPersistence.setLower(relativeHumidity: relativeHumidity, for: uuid)
        postAlertDidChange(with: uuid)
    }

    func upperRelativeHumidity(for uuid: String) -> Double? {
        return alertPersistence.upperRelativeHumidity(for: uuid)
    }

    func setUpper(relativeHumidity: Double?, for uuid: String) {
        alertPersistence.setUpper(relativeHumidity: relativeHumidity, for: uuid)
        postAlertDidChange(with: uuid)
    }

    func relativeHumidityDescription(for uuid: String) -> String? {
        return alertPersistence.relativeHumidityDescription(for: uuid)
    }

    func setRelativeHumidity(description: String?, for uuid: String) {
        alertPersistence.setRelativeHumidity(description: description, for: uuid)
        postAlertDidChange(with: uuid)
    }

}
