import Foundation
import LightRoute
import RuuviLocal
import RuuviOntology
import UIKit

class CardsRouter: NSObject, CardsRouterInput {
    var flags: RuuviLocalFlags!
    weak var transitionHandler: UIViewController?
    var cardsSettingsCoordinator: CardsSettingsCoordinator!
    private weak var dfuModule: DFUModuleInput?

    func dismiss() {
        transitionHandler?
            .navigationController?
            .popToRootViewController(animated: true)
    }

    func openTagSettings(
        snapshot: RuuviTagCardSnapshot,
        ruuviTag: RuuviTagSensor,
        latestMeasurement: RuuviTagSensorRecord?,
        sensorSettings: SensorSettings?,
        output: LegacyTagSettingsModuleOutput
    ) {
        if flags.showImprovedSensorSettingsUI, let transitionHandler {
            cardsSettingsCoordinator = CardsSettingsCoordinator(
                baseViewController: transitionHandler,
                for: snapshot,
                ruuviTagSensor: ruuviTag,
                sensorSettings: sensorSettings,
                delegate: self
            )
            cardsSettingsCoordinator.start()
        } else {
            let factory: LegacyTagSettingsModuleFactory = LegacyTagSettingsModuleFactoryImpl()
            let module = factory.create()
            transitionHandler?
                .navigationController?
                .pushViewController(
                    module,
                    animated: true
                )
            if let presenter = module.output as? LegacyTagSettingsModuleInput {
                presenter.configure(output: output)
                presenter.configure(
                    ruuviTag: ruuviTag,
                    latestMeasurement: latestMeasurement,
                    sensorSettings: sensorSettings
                )
            }
        }
    }

    func openUpdateFirmware(ruuviTag: RuuviTagSensor) {
        let factory: DFUModuleFactory = DFUModuleFactoryImpl()
        let module = factory.create(for: ruuviTag)
        module.output = self
        dfuModule = module
        transitionHandler?
            .present(
                module.viewController,
                animated: true
            )
        module.viewController
            .presentationController?
            .delegate = self
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

extension CardsRouter: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        dfuModule?.isSafeToDismiss() ?? true
    }
}

extension CardsRouter: DFUModuleOutput {
    func dfuModuleSuccessfullyUpgraded(_ dfuModule: DFUModuleInput) {
        dfuModule.viewController.dismiss(animated: true)
    }
}

extension CardsRouter: CardsSettingsCoordinatorDelegate {
    func cardsSettingsCoordinatorDidDismiss(
        _ coordinator: CardsSettingsCoordinator
    ) {
        cardsSettingsCoordinator.stop()
        cardsSettingsCoordinator = nil
    }
}
