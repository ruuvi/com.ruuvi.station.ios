import Foundation

protocol WebTagSettingsViewInput: ViewInput {
    var viewModel: WebTagSettingsViewModel { get set }
    var isNameChangedEnabled: Bool { get set }

    func updateScrollPosition(scrollToAlert: Bool)
    func showTagRemovalConfirmationDialog()
    func showClearLocationConfirmationDialog()
    func showBothNoPNPermissionAndNoLocationPermission()
}
