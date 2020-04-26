import Foundation

protocol KaltiotPickerModuleInput: class {
    func configure(output: KaltiotPickerModuleOutput)
    func popViewController(animated: Bool)
}
