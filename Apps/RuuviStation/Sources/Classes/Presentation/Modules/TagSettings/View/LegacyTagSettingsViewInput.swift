import Foundation
import RuuviOntology

protocol LegacyTagSettingsViewInput: ViewInput {
    var viewModel: LegacyTagSettingsViewModel? { get set }
    var dashboardSortingType: DashboardSortingType? { get set }
    var maxShareCount: Int { get set }

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
