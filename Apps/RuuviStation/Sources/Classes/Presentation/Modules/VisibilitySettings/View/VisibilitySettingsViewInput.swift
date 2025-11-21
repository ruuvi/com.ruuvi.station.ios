import Foundation

protocol VisibilitySettingsViewInput: AnyObject {
    func display(viewModel: VisibilitySettingsViewModel)
    func setUseDefaultSwitch(isOn: Bool)
    func setSaving(_ isSaving: Bool)
    func showMessage(_ message: String)
    // swiftlint:disable:next function_parameter_count
    func presentConfirmation(
        title: String?,
        message: String,
        confirmTitle: String,
        cancelTitle: String,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)?
    )
}
