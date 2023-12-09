import Foundation
import RuuviOntology
import UIKit

protocol TagSettingsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func dismissToRoot(completion: (() -> Void)?)
    func openBackgroundSelectionView(ruuviTag: RuuviTagSensor)
    func openShare(for sensor: RuuviTagSensor)
    func openOffsetCorrection(type: OffsetCorrectionType,
                              ruuviTag: RuuviTagSensor,
                              sensorSettings: SensorSettings?)
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func openOwner(ruuviTag: RuuviTagSensor, mode: OwnershipMode)
    func openContest(ruuviTag: RuuviTagSensor)
    func openSensorRemoval(
        ruuviTag: RuuviTagSensor,
        output: SensorRemovalModuleOutput
    )
}

extension TagSettingsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
