import Foundation

protocol AddMacModalRouterInput {
    func dismiss(completion: (() -> Void)?)
}
extension AddMacModalRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
