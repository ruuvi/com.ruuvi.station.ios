import Foundation

protocol TagSettingsViewInput: ViewInput {
    var viewModel: TagSettingsViewModel? { get set }

    func showTagClaimDialog()
    func showMacAddressDetail()
    func showFirmwareUpdateDialog()
    func showFirmwareDismissConfirmationUpdateDialog()
    func resetKeepConnectionSwitch()
    func showKeepConnectionTimeoutDialog()
    func showKeepConnectionCloudModeDialog()
    func stopKeepConnectionAnimatingDots()
    func startKeepConnectionAnimatingDots()
    func showCSVExportLocationDialog()
}
