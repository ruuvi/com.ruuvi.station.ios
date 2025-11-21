import LightRoute
import RuuviOntology
import RuuviUser
import SwiftUI
import UIKit

class CardsSettingsRouter: NSObject, CardsSettingsRouterInput {
    weak var transitionHandler: UIViewController!
    private weak var dfuModule: DFUModuleInput?
    private var backgroundSelectionModule: BackgroundSelectionModuleInput?

    func dismiss(completion: (() -> Void)?) {
        try! transitionHandler.closeCurrentModule().perform()
        completion?()
    }

    func dismissToRoot(completion: (() -> Void)?) {
        transitionHandler.navigationController?.popViewController(animated: true)
        completion?()
    }

    func openBackgroundSelectionView(ruuviTag: RuuviTagSensor) {
        let factory: BackgroundSelectionModuleFactory = BackgroundSelectionModuleFactoryImpl()
        let module = factory.create(for: ruuviTag)
        backgroundSelectionModule = module
        transitionHandler
            .navigationController?
            .pushViewController(
                module.viewController,
                animated: true
            )
    }

    func openShare(for sensor: RuuviTagSensor) {
        let restorationId = "ShareViewController"
        let factory = StoryboardFactory(storyboardName: "Share", bundle: .main, restorationId: restorationId)
        try? transitionHandler
            .forStoryboard(
                factory: factory,
                to: ShareModuleInput.self
            )
            .to(preferred: .navigation(style: .push))
            .then { module -> Any? in
                module.configure(sensor: sensor)
            }
    }

    func openOffsetCorrection(
        type: OffsetCorrectionType,
        ruuviTag: RuuviTagSensor,
        sensorSettings: SensorSettings?
    ) {
        let factory = StoryboardFactory(storyboardName: "OffsetCorrection")
        try? transitionHandler
            .forStoryboard(factory: factory, to: OffsetCorrectionModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then { module -> Any? in
                module.configure(type: type, ruuviTag: ruuviTag, sensorSettings: sensorSettings)
            }
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

    func openOwner(ruuviTag: RuuviTagSensor, mode: OwnershipMode) {
        let factory = StoryboardFactory(storyboardName: "Owner")
        try? transitionHandler
            .forStoryboard(factory: factory, to: OwnerModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then { module in
                module.configure(ruuviTag: ruuviTag, mode: mode)
            }
    }

    func openContest(ruuviTag: RuuviTagSensor) {
        let factory: SensorForceClaimModuleFactory = SensorForceClaimModuleFactoryImpl()
        let module = factory.create()
        transitionHandler
            .navigationController?
            .pushViewController(
                module,
                animated: true
            )
        if let presenter = module.output as? SensorForceClaimModuleInput {
            presenter.configure(ruuviTag: ruuviTag)
        }
    }

    func openSensorRemoval(
        ruuviTag: RuuviTagSensor,
        output: SensorRemovalModuleOutput
    ) {
        let factory: SensorRemovalModuleFactory = SensorRemovalModuleFactoryImpl()
        let module = factory.create()
        transitionHandler
            .navigationController?
            .pushViewController(
                module,
                animated: true
            )
        if let presenter = module.output as? SensorRemovalModuleInput {
            presenter.configure(ruuviTag: ruuviTag, output: output)
        }
    }
}

extension CardsSettingsRouter: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        dfuModule?.isSafeToDismiss() ?? true
    }
}

extension CardsSettingsRouter: DFUModuleOutput {
    func dfuModuleSuccessfullyUpgraded(_ dfuModule: DFUModuleInput) {
        dfuModule.viewController.dismiss(animated: true)
    }
}
