import Foundation
import BTKit
import RuuviOntology

protocol CardsViewInput: ViewInput {
    var viewModels: [CardsViewModel] { get set }
    var scrollIndex: Int { get set }
    func scroll(to index: Int,
                immediately: Bool,
                animated: Bool)
    func showBluetoothDisabled(userDeclined: Bool)
    func showSwipeLeftRightHint()
    func showWebTagAPILimitExceededError()
    func showKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel)
    func showFirmwareUpdateDialog(for viewModel: CardsViewModel)
    func showFirmwareDismissConfirmationUpdateDialog(for viewModel: CardsViewModel)
    func showReverseGeocodingFailed()
    func showAlreadyLoggedInAlert(with email: String)
    func showChart(module: UIViewController)
    func dismissChart()
    func viewShouldDismiss()
}

extension CardsViewInput {
    func scroll(to index: Int) {
        scroll(to: index, immediately: false, animated: true)
    }

    func showChart(module: UIViewController) {}
    func dismissChart() {}
}
