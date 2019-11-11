import Foundation

protocol AlertService {
    func alert(for uuid: String, of type: AlertType) -> AlertType?
    func register(type: AlertType, for uuid: String)
    func unregister(type: AlertType, for uuid: String)
    
    func setLower(temperature: Int?, for uuid: String)
    func setUpper(temperature: Int?, for uuid: String) 
}
