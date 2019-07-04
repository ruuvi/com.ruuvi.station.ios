import Foundation

protocol TagSettingsRouterInput {
    func dismiss()
    
    func openHumidityCalibration(ruuviTag: RuuviTagRealm, humidity: Double)
}
