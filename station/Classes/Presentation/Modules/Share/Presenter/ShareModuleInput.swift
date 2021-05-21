import Foundation

protocol ShareModuleInput: AnyObject {
    func configure(ruuviTagId: String)
    func dismiss()
}
