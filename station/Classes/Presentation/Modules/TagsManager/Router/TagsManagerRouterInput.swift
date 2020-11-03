import Foundation

protocol TagsManagerRouterInput {
    func dismiss(completion: (() -> Void)?)
    func showAlert(_ viewModel: TagsManagerAlertViewModel)
}
extension TagsManagerRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
