import Foundation

protocol TagSettingsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openHumidityCalibration(ruuviTag: RuuviTagSensor, humidity: Double)
    func openShare(for ruuviTagId: String)
    func openOffsetCorrection(type: OffsetCorrectionType,
                              ruuviTag: RuuviTagSensor,
                              sensorSettings: SensorSettings?)
}
extension TagSettingsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
