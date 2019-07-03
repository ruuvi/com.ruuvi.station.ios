import LightRoute

class TagSettingsRouter: TagSettingsRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }
}
