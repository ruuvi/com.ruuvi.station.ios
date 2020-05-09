import Foundation

protocol KaltiotPickerRouterInput {
    func dismiss(completion: (() -> Void)?)
}
extension KaltiotPickerRouterInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
