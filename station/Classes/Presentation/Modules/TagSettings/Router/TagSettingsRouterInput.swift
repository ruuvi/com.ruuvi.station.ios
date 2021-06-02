import Foundation
import RuuviOntology

protocol TagSettingsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openShare(for ruuviTagId: String)
    func openOffsetCorrection(type: OffsetCorrectionType,
                              ruuviTag: RuuviTagSensor,
                              sensorSettings: SensorSettings?)
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
}
extension TagSettingsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
