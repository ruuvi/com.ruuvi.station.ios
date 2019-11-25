import Foundation

protocol AlertPersistence {
    
    func alert(for uuid: String, of type: AlertType) -> AlertType?
    func register(type: AlertType, for uuid: String)
    func unregister(type: AlertType, for uuid: String)
    
    // temperature
    func lowerCelsius(for uuid: String) -> Double?
    func setLower(celsius: Double?, for uuid: String)
    func upperCelsius(for uuid: String) -> Double? 
    func setUpper(celsius: Double?, for uuid: String)
    func temperatureDescription(for uuid: String) -> String?
    func setTemperature(description: String?, for uuid: String)
}
