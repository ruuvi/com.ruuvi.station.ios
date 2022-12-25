import LightRoute
import Foundation
import UIKit
import RuuviOntology
import RuuviLocal
import RuuviVirtual

class CardsRouter: NSObject, CardsRouterInput {
    weak var transitionHandler: UIViewController?
    private weak var dfuModule: DFUModuleInput?

    func dismiss() {
        try! transitionHandler?.closeCurrentModule().perform()
    }

    func openTagSettings(ruuviTag: RuuviTagSensor,
                         latestMeasurement: RuuviTagSensorRecord,
                         sensorSettings: SensorSettings?,
                         scrollToAlert: Bool,
                         output: TagSettingsModuleOutput) {
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

    func openVirtualSensorSettings(
        sensor: VirtualTagSensor,
        temperature: Temperature?
    ) {
        let factory = StoryboardFactory(storyboardName: "WebTagSettings")
        try! transitionHandler?
            .forStoryboard(factory: factory, to: WebTagSettingsModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(sensor: sensor, temperature: temperature)
            })
    }

    func openUpdateFirmware(ruuviTag: RuuviTagSensor) {
        let factory: DFUModuleFactory = DFUModuleFactoryImpl()
        let module = factory.create(for: ruuviTag)
        self.dfuModule = module
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
}
