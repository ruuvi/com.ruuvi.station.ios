import LightRoute

class NetworkSettingsRouter: NetworkSettingsRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }
}
