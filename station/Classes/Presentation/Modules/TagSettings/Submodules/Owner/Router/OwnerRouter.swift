import LightRoute

final class OwnerRouter: OwnerRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }
}
