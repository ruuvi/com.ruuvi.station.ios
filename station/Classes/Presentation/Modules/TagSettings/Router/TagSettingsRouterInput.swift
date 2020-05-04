import Foundation

protocol TagSettingsRouterInput {
    func dismiss()

    func openHumidityCalibration(ruuviTag: RuuviTagSensor, humidity: Double)
}
