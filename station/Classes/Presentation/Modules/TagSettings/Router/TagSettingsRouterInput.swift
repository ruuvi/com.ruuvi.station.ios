import Foundation
import RuuviOntology

protocol TagSettingsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openShare(for sensor: RuuviTagSensor)
    func openOffsetCorrection(type: OffsetCorrectionType,
                              ruuviTag: RuuviTagSensor,
                              sensorSettings: SensorSettings?)
}
extension TagSettingsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
