import Foundation

protocol TagSettingsRouterInput {
    func dismiss(completion: (() -> Void)?)

    func openHumidityCalibration(ruuviTag: RuuviTagSensor, humidity: Double)
}
extension TagSettingsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
