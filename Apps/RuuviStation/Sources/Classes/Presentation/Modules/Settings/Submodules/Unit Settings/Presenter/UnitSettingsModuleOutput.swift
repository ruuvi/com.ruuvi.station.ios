import Foundation

protocol UnitSettingsModuleOutput {
    func settings(module: UnitSettingsModuleInput, didSelectItem item: SelectionItemProtocol)
}
