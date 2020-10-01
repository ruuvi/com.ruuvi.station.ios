import Foundation

protocol SelectionModuleOutput {
    func selection(module: SelectionModuleInput, didSelectItem item: SelectionItemProtocol)
}
