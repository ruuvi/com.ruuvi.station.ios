import LightRoute

class SettingsRouter: SettingsRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }
}
