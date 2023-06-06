import LightRoute

class SensorForceClaimRouter: SensorForceClaimRouterInput {
    weak var transitionHandler: UIViewController?

    func dismiss() {
        try? transitionHandler?.closeCurrentModule().perform()
    }
}
