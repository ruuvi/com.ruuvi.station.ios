import Foundation
import BTKit

protocol CardsViewInput: ViewInput {
    var viewModels: [CardsViewModel] { get set }
    var currentPage: Int { get }
    func scroll(to index: Int, immediately: Bool, animated: Bool)
    func showNoSensorsAddedMessage(show: Bool)
    func showBluetoothDisabled(userDeclined: Bool)
    func showSwipeLeftRightHint()
    func showWebTagAPILimitExceededError()
    func showKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel, scrollToAlert: Bool)
    func showFirmwareUpdateDialog(for viewModel: CardsViewModel)
    func showFirmwareDismissConfirmationUpdateDialog(for viewModel: CardsViewModel)
    func showReverseGeocodingFailed()
    func showAlreadyLoggedInAlert(with email: String)
}

extension CardsViewInput {
    func scroll(to index: Int) {
        scroll(to: index, immediately: false, animated: true)
    }
}
