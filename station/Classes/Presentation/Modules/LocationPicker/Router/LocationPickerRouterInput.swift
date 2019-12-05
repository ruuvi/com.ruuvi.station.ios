import Foundation

protocol LocationPickerRouterInput {
    func dismiss(completion: (() -> Void)?)
}

extension LocationPickerRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
