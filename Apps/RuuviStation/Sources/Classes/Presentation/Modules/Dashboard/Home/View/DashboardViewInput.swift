import BTKit
import Foundation
import RuuviOntology

protocol DashboardViewInput: ViewInput {
    var viewModels: [CardsViewModel] { get set }
    var dashboardType: DashboardType! { get set }
    var dashboardTapActionType: DashboardTapActionType! { get set }
    var dashboardSortingType: DashboardSortingType! { get set }
    var userSignedInOnce: Bool { get set }
    var isAuthorized: Bool { get set }
    var shouldShowSignInBanner: Bool { get set }
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
