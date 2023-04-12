import Foundation
import BTKit
import RuuviOntology

protocol DashboardViewInput: ViewInput {
    var viewModels: [CardsViewModel] { get set }
    var dashboardType: DashboardType! { get set }
    var showHistoryOnCardTap: Bool { get set }
    func applyUpdate(to viewModel: CardsViewModel)
    func showNoSensorsAddedMessage(show: Bool)
    func showBluetoothDisabled(userDeclined: Bool)
    func showWebTagAPILimitExceededError()
    func showKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel)
    func showReverseGeocodingFailed()
    func showAlreadyLoggedInAlert(with email: String)
}
