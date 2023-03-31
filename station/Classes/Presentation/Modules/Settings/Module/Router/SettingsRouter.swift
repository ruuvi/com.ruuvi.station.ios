import LightRoute
import UIKit

class SettingsRouter: SettingsRouterInput {
    weak var transitionHandler: UIViewController!
    private var ruuviCloudModule: RuuviCloudModuleInput?
    private var devicesModule: DevicesModuleInput?

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openDefaults() {
        let factory = StoryboardFactory(storyboardName: "Defaults")
        try! transitionHandler
            .forStoryboard(factory: factory, to: DefaultsModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ module in
                module.configure()
            })
    }

    func openDevices() {
        let factory: DevicesModuleFactory = DevicesModuleFactoryImpl()
        let module = factory.create()
        self.devicesModule = module
        transitionHandler
            .navigationController?
            .pushViewController(
                module.viewController,
                animated: true
            )
    }

    func openHeartbeat() {
        let factory = StoryboardFactory(storyboardName: "Heartbeat")
        try! transitionHandler
            .forStoryboard(factory: factory, to: HeartbeatModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ module in
                module.configure()
            })
    }

    func openChart() {
        let factory = StoryboardFactory(storyboardName: "ChartSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: ChartSettingsModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ module in
                module.configure()
            })
    }

    func openFeatureToggles() {
        let r = AppAssembly.shared.assembler.resolver
        if let viewController = r.resolve(FLEXFeatureTogglesViewController.self) {
            transitionHandler.navigationController?.pushViewController(
                viewController,
                animated: true
            )
        } else {
            assertionFailure()
        }
    }

    func openUnitSettings(with viewModel: UnitSettingsViewModel, output: UnitSettingsModuleOutput?) {
        let factory = StoryboardFactory(storyboardName: "UnitSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: UnitSettingsModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ module in
                module.configure(viewModel: viewModel, output: output)
            })
    }

    func openRuuviCloud() {
        let factory: RuuviCloudModuleFactory = RuuviCloudModuleFactoryImpl()
        let module = factory.create()
        self.ruuviCloudModule = module
        transitionHandler
            .navigationController?
            .pushViewController(
                module.viewController,
                animated: true
            )
    }

    func openAppearance() {
        let factory: AppearanceSettingsModuleFactory = AppearanceSettingsModuleFactoryImpl()
        let module = factory.create()
        transitionHandler
            .navigationController?
            .pushViewController(
                module,
                animated: true
            )
    }
}
