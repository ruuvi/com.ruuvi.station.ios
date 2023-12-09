import Foundation
import LightRoute
import RuuviLocal
import RuuviOntology
import UIKit

class CardsRouter: NSObject, CardsRouterInput {
    weak var transitionHandler: UIViewController?
    private weak var dfuModule: DFUModuleInput?

    func dismiss() {
        transitionHandler?
            .navigationController?
            .popToRootViewController(animated: true)
    }

    func openTagSettings(ruuviTag: RuuviTagSensor,
                         latestMeasurement: RuuviTagSensorRecord?,
                         sensorSettings: SensorSettings?,
                         output: TagSettingsModuleOutput)
    {
        let factory: TagSettingsModuleFactory = TagSettingsModuleFactoryImpl()
        let module = factory.create()
        transitionHandler?
            .navigationController?
            .pushViewController(
                module,
                animated: true
            )
        if let presenter = module.output as? TagSettingsModuleInput {
            presenter.configure(output: output)
            presenter.configure(ruuviTag: ruuviTag,
                                latestMeasurement: latestMeasurement,
                                sensorSettings: sensorSettings)
        }
    }

    func openUpdateFirmware(ruuviTag: RuuviTagSensor) {
        let factory: DFUModuleFactory = DFUModuleFactoryImpl()
        let module = factory.create(for: ruuviTag)
        dfuModule = module
        transitionHandler?
            .navigationController?
            .pushViewController(
                module.viewController,
                animated: true
            )
    }
}

extension CardsRouter: DiscoverRouterDelegate {
    func discoverRouterWantsClose(_ router: DiscoverRouter) {
        router.viewController.dismiss(animated: true)
    }

    func discoverRouterWantsCloseWithRuuviTagNavigation(
        _ router: DiscoverRouter,
        ruuviTag _: RuuviTagSensor
    ) {
        router.viewController.dismiss(animated: true)
    }
}
