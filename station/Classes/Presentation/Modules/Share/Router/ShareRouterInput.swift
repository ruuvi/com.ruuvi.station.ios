import Foundation

protocol ShareRouterInput {
    func dismiss(completion: (() -> Void)?)
    func showAlert(_ viewModel: AlertViewModel)
}
extension ShareRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
