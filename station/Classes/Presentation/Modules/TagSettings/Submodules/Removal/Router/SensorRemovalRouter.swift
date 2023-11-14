import LightRoute

class SensorRemovalRouter: SensorRemovalRouterInput {
    weak var transitionHandler: UIViewController?

    func dismiss(completion: (() -> Void)?) {
        try? transitionHandler?.closeCurrentModule().perform()
        completion?()
    }
}
