import Foundation
import RuuviOntology

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
    func openLedBrightnessSettings(
        selection: RuuviLedBrightnessLevel?,
        firmwareVersion: String?,
        snapshotId: String?,
        onUpdateFirmware: (() -> Void)?,
        onSelection: @escaping (
            RuuviLedBrightnessLevel,
            @escaping (
                Result<
                Void,
                Error
                >
            ) -> Void
        ) -> Void
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
