import Foundation
import BTKit
import RuuviOntology

protocol DashboardViewInput: ViewInput {
    var viewModels: [CardsViewModel] { get set }
    var dashboardType: DashboardType! { get set }
    func applyUpdate(to viewModel: CardsViewModel)
    func scroll(to index: Int, immediately: Bool, animated: Bool)
    func showNoSensorsAddedMessage(show: Bool)
    func showBluetoothDisabled(userDeclined: Bool)
    func showWebTagAPILimitExceededError()
    func showKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel)
    func showReverseGeocodingFailed()
    func showAlreadyLoggedInAlert(with email: String)
}

extension DashboardViewInput {
    func scroll(to index: Int) {
        scroll(to: index, immediately: false, animated: true)
    }
}
