import BTKit
import Foundation
import RuuviOntology

protocol NewDashboardViewInput: ViewInput {
    var store: SensorStore? { get set }


    var viewModels: [CardsViewModel] { get set }
    var dashboardType: DashboardType { get set }
    var dashboardTapActionType: DashboardTapActionType { get set }
    var dashboardSortingType: DashboardSortingType { get set }
    var isRefreshing: Bool { get set }
    var shouldShowSignInBanner: Bool { get set }
    func showNoSensorsAddedMessage(show: Bool)
    func showBluetoothDisabled(userDeclined: Bool)
    func showKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel)
    func showAlreadyLoggedInAlert(with email: String)
    func showSensorNameRenameDialog(
        for viewModel: CardsViewModel,
        sortingType: DashboardSortingType
    )
    func showSensorSortingResetConfirmationDialog()
}
