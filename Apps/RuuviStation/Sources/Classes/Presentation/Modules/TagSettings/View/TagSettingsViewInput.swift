import Foundation
import RuuviOntology

protocol TagSettingsViewInput: ViewInput {
    var viewModel: TagSettingsViewModel? { get set }
    var dashboardSortingType: DashboardSortingType? { get set }

    func showTagClaimDialog()
    func showMacAddressDetail()
    func showFirmwareUpdateDialog()
    func showFirmwareDismissConfirmationUpdateDialog()
    func resetKeepConnectionSwitch()
    func showKeepConnectionTimeoutDialog()
    func showKeepConnectionCloudModeDialog()
    func stopKeepConnectionAnimatingDots()
    func startKeepConnectionAnimatingDots()
}
