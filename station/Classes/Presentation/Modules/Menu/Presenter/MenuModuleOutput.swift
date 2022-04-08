import Foundation

protocol MenuModuleOutput: AnyObject {
    func menu(module: MenuModuleInput, didSelectAddRuuviTag sender: Any?)
    func menu(module: MenuModuleInput, didSelectSettings sender: Any?)
    func menu(module: MenuModuleInput, didSelectAbout sender: Any?)
    func menu(module: MenuModuleInput, didSelectGetMoreSensors sender: Any?)
    func menu(module: MenuModuleInput, didSelectGetRuuviGateway sender: Any?)
    func menu(module: MenuModuleInput, didSelectFeedback sender: Any?)
    func menu(module: MenuModuleInput, didSelectSignIn sender: Any?)
    func menu(module: MenuModuleInput, didSelectOpenConfig sender: Any?)
}
