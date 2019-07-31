import LightRoute

class LocationPickerRouter: LocationPickerRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }
}
