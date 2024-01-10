import LightRoute
import RuuviOntology
import UIKit

final class OwnerRouter: NSObject, OwnerRouterInput {
    weak var transitionHandler: UIViewController!
    private weak var dfuModule: DFUModuleInput?

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openUpdateFirmware(ruuviTag: RuuviTagSensor) {
        let factory: DFUModuleFactory = DFUModuleFactoryImpl()
        let module = factory.create(for: ruuviTag)
        module.output = self
        dfuModule = module
        transitionHandler
            .present(
                module.viewController,
                animated: true
            )
        module.viewController
            .presentationController?
            .delegate = self
    }
}

extension OwnerRouter: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        dfuModule?.isSafeToDismiss() ?? true
    }
}

extension OwnerRouter: DFUModuleOutput {
    func dfuModuleSuccessfullyUpgraded(_ dfuModule: DFUModuleInput) {
        dfuModule.viewController.dismiss(animated: true)
    }
}
