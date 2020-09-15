import Foundation

protocol SelectionModuleInput: class {
    func configure(dataSource: [SelectionItemProtocol], output: SelectionModuleOutput?)
    func dismiss()
}
