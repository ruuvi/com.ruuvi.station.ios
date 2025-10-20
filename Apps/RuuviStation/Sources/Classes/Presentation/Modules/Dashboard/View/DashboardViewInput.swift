import BTKit
import Foundation
import RuuviOntology

protocol NewDashboardViewInput: ViewInput {
    var isAuthorized: Bool { get set }
    var dashboardType: DashboardType! { get set }
    var dashboardTapActionType: DashboardTapActionType! { get set }
    var dashboardSortingType: DashboardSortingType! { get set }
    var isRefreshing: Bool { get set }
    var shouldShowSignInBanner: Bool { get set }
    func updateSnapshots(
        _ snapshots: [RuuviTagCardSnapshot],
        withAnimation: Bool
    )
    func updateSnapshot(
        from snapshot: RuuviTagCardSnapshot,
        invalidateLayout: Bool
    )
    func showNoSensorsAddedMessage(show: Bool)
    func showBluetoothDisabled(userDeclined: Bool)
    func showKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot)
    func showKeepConnectionDialogSettings(
        for snapshot: RuuviTagCardSnapshot,
        newlyAddedSensor: Bool
    )
    func showAlreadyLoggedInAlert(with email: String)
    func showSensorNameRenameDialog(
        for snapshot: RuuviTagCardSnapshot,
        sortingType: DashboardSortingType
    )
    func showSensorSortingResetConfirmationDialog()
}

extension NewDashboardViewInput {
    func updateSnapshot(
        from snapshot: RuuviTagCardSnapshot,
        invalidateLayout: Bool = false
    ) {
        updateSnapshot(from: snapshot, invalidateLayout: invalidateLayout)
    }
}
