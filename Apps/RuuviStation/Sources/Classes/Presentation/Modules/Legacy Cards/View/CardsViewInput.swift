import BTKit
import Foundation
import RuuviOntology
import UIKit

protocol CardsViewInput: ViewInput {
    var viewModels: [CardsViewModel] { get set }
    var scrollIndex: Int { get set }
    var isRefreshing: Bool { get set }
    func applyUpdate(to viewModel: CardsViewModel)
    func scroll(to index: Int)
    func showBluetoothDisabled(userDeclined: Bool)
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
    func showChart(module _: UIViewController) {}
    func dismissChart() {}
}
