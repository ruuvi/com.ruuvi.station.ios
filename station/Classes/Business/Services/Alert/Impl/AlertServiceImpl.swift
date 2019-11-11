import Foundation

class AlertServiceImpl: AlertService {
    
    var alertPersistence: AlertPersistence!
    
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
}
