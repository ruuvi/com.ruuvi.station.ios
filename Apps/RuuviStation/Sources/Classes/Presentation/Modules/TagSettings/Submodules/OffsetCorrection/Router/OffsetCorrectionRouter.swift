import LightRoute

class OffsetCorrectionRouter: OffsetCorrectionRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }
}
