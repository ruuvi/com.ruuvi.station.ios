import Foundation

protocol MenuModuleOutput: class {
    func menu(module: MenuModuleInput, didSelectAddRuuviTag sender: Any?)
    func menu(module: MenuModuleInput, didSelectSettings sender: Any?)
}
