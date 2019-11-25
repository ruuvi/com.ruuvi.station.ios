import Foundation

class AlertPersistenceUserDefaults: AlertPersistence {
    
    private let prefs = UserDefaults.standard
    private let temperatureLowerBoundUDKeyPrefix = "AlertPersistenceUserDefaults.temperatureLowerBoundUDKeyPrefix."
    private let temperatureUpperBoundUDKeyPrefix = "AlertPersistenceUserDefaults.temperatureUpperBoundUDKeyPrefix."
    private let temperatureAlertIsOnUDKeyPrefix = "AlertPersistenceUserDefaults.temperatureAlertIsOnUDKeyPrefix."
    
    func alert(for uuid: String, of type: AlertType) -> AlertType? {
        switch type {
        case .temperature:
            if prefs.bool(forKey: temperatureAlertIsOnUDKeyPrefix + uuid),
                let lower = prefs.optionalDouble(forKey: temperatureLowerBoundUDKeyPrefix + uuid),
                let upper = prefs.optionalDouble(forKey: temperatureUpperBoundUDKeyPrefix + uuid) {
                return .temperature(lower: lower, upper: upper)
            } else {
                return nil
            }
        }
    }
    
    func register(type: AlertType, for uuid: String) {
        switch type {
        case .temperature(let lower, let upper):
            prefs.set(true, forKey: temperatureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
        }
    }
    
    func unregister(type: AlertType, for uuid: String) {
        switch type {
        case .temperature:
            prefs.set(false, forKey: temperatureAlertIsOnUDKeyPrefix + uuid)
        }
    }
    
    func lowerCelsius(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: temperatureLowerBoundUDKeyPrefix + uuid)
    }
    
    func upperCelsius(for uuid: String) -> Double? {
        return prefs.optionalDouble(forKey: temperatureUpperBoundUDKeyPrefix + uuid)
    }
    
    func setLower(celsius: Double?, for uuid: String) {
        prefs.set(celsius, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
    }
    
    func setUpper(celsius: Double?, for uuid: String) {
        prefs.set(celsius, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
    }    
}
