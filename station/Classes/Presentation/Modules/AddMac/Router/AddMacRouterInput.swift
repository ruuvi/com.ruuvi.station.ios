import Foundation

protocol AddMacRouterInput {
    func dismiss(completion: (() -> Void)?)
}
extension AddMacRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
