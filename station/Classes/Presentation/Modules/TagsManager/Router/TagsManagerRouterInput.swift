import Foundation

protocol TagsManagerRouterInput {
    func dismiss(completion: (() -> Void)?)
    func showAlert(_ viewModel: AlertViewModel)
}
extension TagsManagerRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
