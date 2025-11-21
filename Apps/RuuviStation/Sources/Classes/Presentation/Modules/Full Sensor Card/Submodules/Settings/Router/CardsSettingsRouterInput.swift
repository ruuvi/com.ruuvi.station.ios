import Foundation
import RuuviOntology
import UIKit

protocol CardsSettingsRouterInput {
    func dismiss(completion: (() -> Void)?)
    func dismissToRoot(completion: (() -> Void)?)
    func openBackgroundSelectionView(ruuviTag: RuuviTagSensor)
    func openShare(for sensor: RuuviTagSensor)
    func openOffsetCorrection(
        type: OffsetCorrectionType,
        ruuviTag: RuuviTagSensor,
        sensorSettings: SensorSettings?
    )
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func openOwner(ruuviTag: RuuviTagSensor, mode: OwnershipMode)
    func openContest(ruuviTag: RuuviTagSensor)
    func openSensorRemoval(
        ruuviTag: RuuviTagSensor,
        output: SensorRemovalModuleOutput
    )
    func openVisibilitySettings(
        snapshot: RuuviTagCardSnapshot,
        ruuviTag: RuuviTagSensor,
        sensorSettings: SensorSettings?
    )
}

extension CardsSettingsRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
