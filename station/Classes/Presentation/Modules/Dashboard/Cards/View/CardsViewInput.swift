import Foundation
import BTKit
import RuuviOntology
import UIKit

protocol CardsViewInput: ViewInput {
    var viewModels: [CardsViewModel] { get set }
    var scrollIndex: Int { get set }
    func applyUpdate(to viewModel: CardsViewModel)
    func changeCardBackground(of viewModel: CardsViewModel, to image: UIImage?)
    func scroll(to index: Int)
    func showBluetoothDisabled(userDeclined: Bool)
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
    func showChart(module: UIViewController) {}
    func dismissChart() {}
}
