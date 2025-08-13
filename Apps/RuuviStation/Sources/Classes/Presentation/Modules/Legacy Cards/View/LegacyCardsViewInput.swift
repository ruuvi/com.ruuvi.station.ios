import BTKit
import Foundation
import RuuviOntology
import UIKit

protocol LegacyCardsViewInput: ViewInput {
    var viewModels: [LegacyCardsViewModel] { get set }
    var scrollIndex: Int { get set }
    var isRefreshing: Bool { get set }
    func applyUpdate(to viewModel: LegacyCardsViewModel)
    func scroll(to index: Int)
    func showBluetoothDisabled(userDeclined: Bool)
    func showKeepConnectionDialogChart(for viewModel: LegacyCardsViewModel)
    func showKeepConnectionDialogSettings(for viewModel: LegacyCardsViewModel)
    func showFirmwareUpdateDialog(for viewModel: LegacyCardsViewModel)
    func showFirmwareDismissConfirmationUpdateDialog(for viewModel: LegacyCardsViewModel)
    func showReverseGeocodingFailed()
    func showAlreadyLoggedInAlert(with email: String)
    func showChart(module: UIViewController)
    func dismissChart()
    func viewShouldDismiss()
}

extension LegacyCardsViewInput {
    func showChart(module _: UIViewController) {}
    func dismissChart() {}
}
