import LightRoute
import RuuviOntology
import UIKit

final class OwnerRouter: OwnerRouterInput {
    weak var transitionHandler: UIViewController!
    private var dfuModule: DFUModuleInput?

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openUpdateFirmware(ruuviTag: RuuviTagSensor) {
        let factory: DFUModuleFactory = DFUModuleFactoryImpl()
        let module = factory.create(for: ruuviTag)
        self.dfuModule = module
        transitionHandler
            .navigationController?
            .pushViewController(
                module.viewController,
                animated: true
            )
    }
}
