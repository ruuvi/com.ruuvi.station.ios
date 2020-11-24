import Foundation

protocol ShareModuleInput: class {
    func configure(ruuviTagId: String)
    func dismiss()
}
