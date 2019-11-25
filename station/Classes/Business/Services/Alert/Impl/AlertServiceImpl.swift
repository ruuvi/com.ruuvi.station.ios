import Foundation
import BTKit

class AlertServiceImpl: AlertService {
    
    var alertPersistence: AlertPersistence!
    var localNotificationsManager: LocalNotificationsManager!
    
    func alert(for uuid: String, of type: AlertType) -> AlertType? {
        return alertPersistence.alert(for: uuid, of: type)
    }
    
    func register(type: AlertType, for uuid: String) {
        alertPersistence.register(type: type, for: uuid)
    }
    
    func unregister(type: AlertType, for uuid: String) {
        alertPersistence.unregister(type: type, for: uuid)
    }
    
    func lowerCelsius(for uuid: String) -> Double? {
        return alertPersistence.lowerCelsius(for: uuid)
    }
    
    func setLower(celsius: Double?, for uuid: String) {
        alertPersistence.setLower(celsius: celsius, for: uuid)
    }
    
    func upperCelsius(for uuid: String) -> Double? {
        return alertPersistence.upperCelsius(for: uuid)
    }
    
    func setUpper(celsius: Double?, for uuid: String) {
        alertPersistence.setUpper(celsius: celsius, for: uuid)
    }
    
    func temperatureDescription(for uuid: String) -> String? {
        return alertPersistence.temperatureDescription(for: uuid)
    }
    
    func setTemperature(description: String?, for uuid: String) {
        alertPersistence.setTemperature(description: description, for: uuid)
    }
    
    func proccess(heartbeat ruuviTag: RuuviTag) {
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                if case .temperature(let lower, let upper) = alert(for: ruuviTag.uuid, of: type), let celsius = ruuviTag.celsius {
                    if celsius < lower {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager.notifyLowTemperature(for: ruuviTag.uuid, celsius: celsius)
                        }
                    } else if celsius > upper {
                        DispatchQueue.main.async { [weak self] in
                            self?.localNotificationsManager.notifyHighTemperature(for: ruuviTag.uuid, celsius: celsius)
                        }
                    }
                }
            }
        }
    }
    
}
