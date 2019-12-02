import LightRoute

class HumidityCalibrationRouter: HumidityCalibrationRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }
}
