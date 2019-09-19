import LightRoute

class TagChartsRouter: TagChartsRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }
}
