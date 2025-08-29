import Foundation
import RuuviOntology

protocol CardsBaseViewInput: AnyObject {
    /// Sets only the tab type and requests presenter to show the contents.
    func setActiveTab(_ tab: CardsMenuType)

    /// Requests view to show contents for the tab. This is called once all the checks
    /// and precondition steps are completed.
    func showContentsForTab(_ tab: CardsMenuType)
    func setSnapshots(_ snapshots: [RuuviTagCardSnapshot])
    func updateSnapshot(_ snapshot: RuuviTagCardSnapshot)
    func setActiveSnapshotIndex(_ index: Int)
    func setActivityIndicatorVisible(_ visible: Bool)
    func showBluetoothDisabled(userDeclined: Bool)
    func showKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot)
    func showKeepConnectionDialogSettings(for snapshot: RuuviTagCardSnapshot)
    func showFirmwareUpdateDialog(for snapshot: RuuviTagCardSnapshot)
    func showFirmwareDismissConfirmationUpdateDialog(for snapshot: RuuviTagCardSnapshot)
    func showMeasurementDetails(
        for indicator: RuuviTagCardSnapshotIndicatorData,
        snapshot: RuuviTagCardSnapshot,
        sensor: RuuviTagSensor,
        settings: SensorSettings?
    )
}
