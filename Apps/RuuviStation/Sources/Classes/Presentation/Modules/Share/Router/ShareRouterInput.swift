import Foundation

protocol ShareRouterInput {
    func dismiss(completion: (() -> Void)?)
}

extension ShareRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
