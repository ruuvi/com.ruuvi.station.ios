import Foundation

protocol TagSettingsViewInput: ViewInput {
    var viewModel: TagSettingsViewModel? { get set }

    func showTagRemovalConfirmationDialog()
    func showMacAddressDetail()
    func showUUIDDetail()
    func showUpdateFirmwareDialog()
    func showBothNotConnectedAndNoPNPermissionDialog()
    func showNotConnectedDialog()
}
