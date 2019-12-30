import Foundation

protocol LocationPickerModuleInput: class {
    func configure(output: LocationPickerModuleOutput)
    func dismiss(completion: (() -> Void)?)
}
