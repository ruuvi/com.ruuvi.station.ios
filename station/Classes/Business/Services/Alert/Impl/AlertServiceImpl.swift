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
    
    func setLower(temperature: Int?, for uuid: String) {
        alertPersistence.setLower(temperature: temperature, for: uuid)
    }
    
    func setUpper(temperature: Int?, for uuid: String) {
        alertPersistence.setUpper(temperature: temperature, for: uuid)
    }
}
