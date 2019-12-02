import LightRoute

class WebTagSettingsRouter: WebTagSettingsRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openLocationPicker(output: LocationPickerModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "LocationPicker")
        try! transitionHandler
            .forStoryboard(factory: factory, to: LocationPickerModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(output: output)
            })
    }
}
