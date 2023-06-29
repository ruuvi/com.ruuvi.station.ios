import Foundation
import UIKit
import RuuviOntology

protocol TagSettingsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func openBackgroundSelectionView(ruuviTag: RuuviTagSensor)
    func openShare(for sensor: RuuviTagSensor)
    func openOffsetCorrection(type: OffsetCorrectionType,
                              ruuviTag: RuuviTagSensor,
                              sensorSettings: SensorSettings?)
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func openOwner(ruuviTag: RuuviTagSensor, mode: OwnershipMode)
    func openContest(ruuviTag: RuuviTagSensor)
}

extension TagSettingsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
