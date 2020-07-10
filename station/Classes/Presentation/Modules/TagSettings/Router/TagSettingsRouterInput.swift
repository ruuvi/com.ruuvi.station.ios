import Foundation

protocol TagSettingsRouterInput {
    func dismiss(completion: (() -> Void)?)

    func openHumidityCalibration(ruuviTag: RuuviTagSensor, humidity: Double)
}
