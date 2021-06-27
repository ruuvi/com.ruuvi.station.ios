import Foundation
import UIKit
import RuuviOntology

protocol TagSettingsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openShare(for sensor: RuuviTagSensor)
    func openOffsetCorrection(type: OffsetCorrectionType,
                              ruuviTag: RuuviTagSensor,
                              sensorSettings: SensorSettings?)
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func macCatalystExportFile(with path: URL, delegate: UIDocumentPickerDelegate?)
}
extension TagSettingsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
