import LightRoute

class UnitSettingsRouter: UnitSettingsRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
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
