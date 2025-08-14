import Foundation
import RuuviOntology

protocol DashboardViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerSignIn()
    func viewDidTriggerAddSensors()
    func viewDidTriggerMenu()
    func viewDidTriggerBuySensors()
    func viewDidTriggerOpenCardImageView(for snapshot: RuuviTagCardSnapshot?)
    func viewDidTriggerOpenSensorCardFromWidget(for snapshot: RuuviTagCardSnapshot?)
    func viewDidTriggerSettings(for snapshot: RuuviTagCardSnapshot)
    func viewDidTriggerChart(for snapshot: RuuviTagCardSnapshot)
    func viewDidTriggerChangeBackground(for snapshot: RuuviTagCardSnapshot)
    func viewDidTriggerRename(for snapshot: RuuviTagCardSnapshot)
    func viewDidTriggerShare(for snapshot: RuuviTagCardSnapshot)
    func viewDidTriggerRemove(for snapshot: RuuviTagCardSnapshot)
    func viewDidTriggerDashboardCard(for snapshot: RuuviTagCardSnapshot)
    func viewDidConfirmToKeepConnectionChart(to snapshot: RuuviTagCardSnapshot)
    func viewDidDismissKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot)
    func viewDidConfirmToKeepConnectionSettings(
        to snapshot: RuuviTagCardSnapshot,
        newlyAddedSensor: Bool
    )
    func viewDidDismissKeepConnectionDialogSettings(
        for snapshot: RuuviTagCardSnapshot,
        newlyAddedSensor: Bool
    )
    func viewDidChangeDashboardType(dashboardType: DashboardType)
    func viewDidChangeDashboardTapAction(type: DashboardTapActionType)
    func viewDidTriggerPullToRefresh()
    func viewDidRenameTag(to name: String, snapshot: RuuviTagCardSnapshot)
    func viewDidReorderSensors(with type: DashboardSortingType, orderedIds: [String])
    func viewDidResetManualSorting()
    func viewDidHideSignInBanner()
}
