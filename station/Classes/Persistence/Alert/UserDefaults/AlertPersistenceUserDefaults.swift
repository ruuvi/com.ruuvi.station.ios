import Foundation

class AlertPersistenceUserDefaults: AlertPersistence {
    
    private let prefs = UserDefaults.standard
    private let temperatureLowerBoundUDKeyPrefix = "AlertPersistenceUserDefaults.temperatureLowerBoundUDKeyPrefix."
    private let temperatureUpperBoundUDKeyPrefix = "AlertPersistenceUserDefaults.temperatureUpperBoundUDKeyPrefix."
    
    func alert(for uuid: String, of type: AlertType) -> AlertType? {
        switch type {
        case .temperature:
            if let lower = prefs.optionalInt(forKey: temperatureLowerBoundUDKeyPrefix + uuid),
                let upper = prefs.optionalInt(forKey: temperatureUpperBoundUDKeyPrefix + uuid) {
                return .temperature(lower: lower, upper: upper)
            } else {
                return nil
            }
        }
    }
    
    func register(type: AlertType, for uuid: String) {
        switch type {
        case .temperature(let lower, let upper):
            prefs.set(lower, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
        }
    }
    
    func unregister(type: AlertType, for uuid: String) {
        switch type {
        case .temperature:
            prefs.set(nil, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
            prefs.set(nil, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
        }
    }
}
