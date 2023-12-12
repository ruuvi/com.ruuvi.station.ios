import LightRoute

class MyRuuviAccountRouter: MyRuuviAccountRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }
}
