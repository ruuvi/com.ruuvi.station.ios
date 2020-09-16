import Foundation

protocol SelectionModuleInput: class {
    func configure(dataSource: [SelectionItemProtocol], title: String, output: SelectionModuleOutput?)
    func dismiss()
}
