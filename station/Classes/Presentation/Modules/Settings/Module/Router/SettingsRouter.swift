import LightRoute
import UIKit

class SettingsRouter: SettingsRouterInput {
    weak var transitionHandler: UIViewController!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openLanguage() {
        let factory = StoryboardFactory(storyboardName: "Language")
        try! transitionHandler
            .forStoryboard(factory: factory, to: LanguageModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .perform()
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

    func openHeartbeat() {
        let factory = StoryboardFactory(storyboardName: "Heartbeat")
        try! transitionHandler
            .forStoryboard(factory: factory, to: HeartbeatModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ module in
                module.configure()
            })
    }

    func openAdvanced() {
        let factory = StoryboardFactory(storyboardName: "AdvancedSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: AdvancedModuleInput.self)
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

    func openSelection(with viewModel: SelectionViewModel, output: SelectionModuleOutput?) {
        let factory = StoryboardFactory(storyboardName: "Selection")
        try! transitionHandler
            .forStoryboard(factory: factory, to: SelectionModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ module in
                module.configure(viewModel: viewModel, output: output)
            })
    }
}
