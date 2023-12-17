import BTKit
import Foundation
import RuuviOntology

protocol DashboardViewInput: ViewInput {
    var viewModels: [CardsViewModel] { get set }
    var dashboardType: DashboardType! { get set }
    var dashboardTapActionType: DashboardTapActionType! { get set }
    var userSignedInOnce: Bool { get set }
    func applyUpdate(to viewModel: CardsViewModel)
    func showNoSensorsAddedMessage(show: Bool)
    func showBluetoothDisabled(userDeclined: Bool)
    func showKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel)
    func showReverseGeocodingFailed()
    func showAlreadyLoggedInAlert(with email: String)
    func showSensorNameRenameDialog(
        for viewModel: CardsViewModel,
        sortingType: DashboardSortingType
    )
    func showSensorSortingResetConfirmationDialog()
}
