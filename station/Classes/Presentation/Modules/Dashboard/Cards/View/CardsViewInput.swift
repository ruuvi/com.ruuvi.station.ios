import Foundation
import BTKit
import RuuviOntology

protocol CardsViewInput: ViewInput {
    var viewModels: [CardsViewModel] { get set }
    var scrollIndex: Int { get set }
    var currentPage: Int { get }
    func applyUpdate(to viewModel: CardsViewModel)
    func changeCardBackground(of viewModel: CardsViewModel, to image: UIImage?)
    func scroll(to index: Int,
                immediately: Bool,
                animated: Bool)
    func showBluetoothDisabled(userDeclined: Bool)
    func showSwipeLeftRightHint()
    func showWebTagAPILimitExceededError()
    func showKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel, scrollToAlert: Bool)
    func showFirmwareUpdateDialog(for viewModel: CardsViewModel)
    func showFirmwareDismissConfirmationUpdateDialog(for viewModel: CardsViewModel)
    func showReverseGeocodingFailed()
    func showAlreadyLoggedInAlert(with email: String)
    // Experiments
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
