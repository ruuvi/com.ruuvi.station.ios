import UIKit
import LightRoute
import SwiftUI
import RuuviOntology
import RuuviUser

class TagSettingsRouter: NSObject, TagSettingsRouterInput {
    weak var transitionHandler: UIViewController!
    private var dfuModule: DFUModuleInput?
    private var backgroundSelectionModule: BackgroundSelectionModuleInput?

    func dismiss(completion: (() -> Void)?) {
        try! transitionHandler.closeCurrentModule().perform()
        completion?()
    }

    func openBackgroundSelectionView(ruuviTag: RuuviTagSensor) {
        let factory: BackgroundSelectionModuleFactory = BackgroundSelectionModuleFactoryImpl()
        let module = factory.create(for: ruuviTag, virtualTag: nil)
        self.backgroundSelectionModule = module
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
        try! transitionHandler
            .forStoryboard(factory: factory,
                           to: ShareModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(sensor: sensor)
            })
    }

    func openOffsetCorrection(type: OffsetCorrectionType,
                              ruuviTag: RuuviTagSensor,
                              sensorSettings: SensorSettings?) {
        let factory = StoryboardFactory(storyboardName: "OffsetCorrection")
        try! transitionHandler
            .forStoryboard(factory: factory, to: OffsetCorrectionModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(type: type, ruuviTag: ruuviTag, sensorSettings: sensorSettings)
            })
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
        transitionHandler
            .navigationController?
            .presentationController?
            .delegate = self
    }

    func openOwner(ruuviTag: RuuviTagSensor, mode: OwnershipMode) {
        let factory = StoryboardFactory(storyboardName: "Owner")
        try! transitionHandler
            .forStoryboard(factory: factory, to: OwnerModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ module in
                module.configure(ruuviTag: ruuviTag, mode: mode)
            })
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
}

extension TagSettingsRouter: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return dfuModule?.isSafeToDismiss() ?? false
    }
}
