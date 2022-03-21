import Foundation

protocol TagSettingsViewInput: ViewInput {
    var viewModel: TagSettingsViewModel? { get set }

    func updateScrollPosition(scrollToAlert: Bool)
    func showTagRemovalConfirmationDialog(isOwner: Bool)
    func showUnclaimAndRemoveConfirmationDialog()
    func showMacAddressDetail()
    func showUpdateFirmwareDialog()
    func showBothNotConnectedAndNoPNPermissionDialog()
    func showNotConnectedDialog()
    func showExportSheet(with path: URL)
}
