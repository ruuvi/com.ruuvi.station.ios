import Foundation

protocol UserApiConfigRouterInput {
    func dismiss(completion: (() -> Void)?)
    func showAlert(_ viewModel: UserApiConfigAlertViewModel)
}
extension UserApiConfigRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
