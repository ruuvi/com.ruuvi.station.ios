import Foundation
import RuuviOntology

protocol CardsBaseViewOutput: AnyObject {
    func appWillMoveToForeground()
    func viewWillAppear()
    func viewDidChangeTab(_ tab: CardsMenuType)
    func viewDidRequestNavigateToSnapshotIndex(_ index: Int)
    func viewDidTapBackButton()
    func viewDidConfirmToKeepConnectionChart(to snapshot: RuuviTagCardSnapshot)
    func viewDidDismissKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot)
    func viewDidConfirmToKeepConnectionSettings(to snapshot: RuuviTagCardSnapshot)
    func viewDidDismissKeepConnectionDialogSettings(for snapshot: RuuviTagCardSnapshot)
    func viewDidConfirmFirmwareUpdate(for snapshot: RuuviTagCardSnapshot)
    /// Trigger this method when user cancel the legacy firmware update dialog for the first time
    func viewDidIgnoreFirmwareUpdateDialog(for snapshot: RuuviTagCardSnapshot)
    /// Trigger this method when user confirms the lagacy firmware update dialog dismiss for the second time
    func viewDidDismissFirmwareUpdateDialog(for snapshot: RuuviTagCardSnapshot)
}
