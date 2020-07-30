import LightRoute

class TagSettingsRouter: TagSettingsRouterInput {
    weak var transitionHandler: TransitionHandler!

    // swiftlint:disable weak_delegate
    private lazy var humidityCalibrationTransitioningDelegate = HumidityCalibrationTransitioningDelegate()
    // swiftlint:enable weak_delegate

    func dismiss(completion: (() -> Void)?) {
        try! transitionHandler.closeCurrentModule().perform()
        completion?()
    }

    func openHumidityCalibration(ruuviTag: RuuviTagSensor, humidity: Double) {
        let factory = StoryboardFactory(storyboardName: "HumidityCalibration")
        try! transitionHandler
            .forStoryboard(factory: factory, to: HumidityCalibrationModuleInput.self)
            .add(transitioningDelegate: humidityCalibrationTransitioningDelegate)
            .apply(to: { (viewController) in
                viewController.modalPresentationStyle = .custom
            })
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag, humidity: humidity)
            })
    }
}
