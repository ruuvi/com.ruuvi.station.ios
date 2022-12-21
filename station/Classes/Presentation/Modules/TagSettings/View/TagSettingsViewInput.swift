import Foundation

protocol TagSettingsViewInput: ViewInput {
    var viewModel: TagSettingsViewModel? { get set }

    func updateScrollPosition(scrollToAlert: Bool)
    func showTagRemovalConfirmationDialog(isOwner: Bool)
    func showUnclaimAndRemoveConfirmationDialog()
    func showMacAddressDetail()
    func showBothNotConnectedAndNoPNPermissionDialog()
    func showNotConnectedDialog()
    func showExportSheet(with path: URL)
    func showFirmwareUpdateDialog()
    func showFirmwareDismissConfirmationUpdateDialog()
    func resetKeepConnectionSwitch()
    func showKeepConnectionTimeoutDialog()
    func showKeepConnectionCloudModeDialog()
    func stopKeepConnectionAnimatingDots()
    func startKeepConnectionAnimatingDots()
}
