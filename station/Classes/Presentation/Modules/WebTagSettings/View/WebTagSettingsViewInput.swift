import Foundation

protocol WebTagSettingsViewInput: ViewInput {
    var viewModel: WebTagSettingsViewModel { get set }
    var isNameChangedEnabled: Bool { get set }

    func showTagRemovalConfirmationDialog()
    func showClearLocationConfirmationDialog()
    func showBothNoPNPermissionAndNoLocationPermission()
}
