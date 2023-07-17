import Foundation

protocol NotificationsSettingsRouterInput {
    func dismiss()
    func openSelection(with viewModel: PushAlertSoundSelectionViewModel)
}
