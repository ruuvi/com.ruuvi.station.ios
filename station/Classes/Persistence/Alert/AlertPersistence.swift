import Foundation

protocol AlertPersistence {
    func alert(for uuid: String, of type: AlertType) -> AlertType?
    func register(type: AlertType, for uuid: String)
    func unregister(type: AlertType, for uuid: String)
    
    func setLower(celsius: Double?, for uuid: String)
    func setUpper(celsius: Double?, for uuid: String) 
}
