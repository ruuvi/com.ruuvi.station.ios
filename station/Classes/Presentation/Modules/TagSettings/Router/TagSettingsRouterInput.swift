import Foundation

protocol TagSettingsRouterInput {
    func dismiss(completion: (() -> Void)?)

    func openHumidityCalibration(ruuviTag: RuuviTagSensor, humidity: Double)

    func openShare(for ruuviTagId: String)
}
extension TagSettingsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
