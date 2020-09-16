import LightRoute

class SettingsRouter: SettingsRouterInput {
    weak var transitionHandler: TransitionHandler!

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

    func openForeground() {
        let factory = StoryboardFactory(storyboardName: "Foreground")
        try! transitionHandler
            .forStoryboard(factory: factory, to: ForegroundModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ module in
                module.configure()
            })
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
