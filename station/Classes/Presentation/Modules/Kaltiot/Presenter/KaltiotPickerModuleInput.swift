import Foundation

protocol KaltiotPickerModuleInput: class {
    func configure(output: KaltiotPickerModuleOutput)
    func dismiss()
}
