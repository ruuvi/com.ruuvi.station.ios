import Foundation

protocol TagsManagerModuleInput: AnyObject {
    func configure(output: TagsManagerModuleOutput)
    func dismiss()
}
