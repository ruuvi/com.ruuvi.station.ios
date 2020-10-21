import Foundation

protocol TagsManagerModuleInput: class {
    func configure(output: TagsManagerModuleOutput)
    func dismiss()
}
