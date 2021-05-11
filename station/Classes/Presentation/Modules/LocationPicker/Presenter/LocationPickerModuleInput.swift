import Foundation

protocol LocationPickerModuleInput: AnyObject {
    func configure(output: LocationPickerModuleOutput)
    func dismiss(completion: (() -> Void)?)
}

extension LocationPickerModuleInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
