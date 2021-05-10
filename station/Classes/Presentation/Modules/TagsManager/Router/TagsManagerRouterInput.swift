import Foundation

protocol TagsManagerRouterInput {
    func dismiss(completion: (() -> Void)?)
}
extension TagsManagerRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
