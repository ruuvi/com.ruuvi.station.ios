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

    func openShare(for ruuviTagId: String) {
        let restorationId = "ShareViewController"
        let factory = StoryboardFactory(storyboardName: "Share", bundle: .main, restorationId: restorationId)
        try! transitionHandler
            .forStoryboard(factory: factory,
                           to: ShareModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(ruuviTagId: ruuviTagId)
            })
    }

    func openOffsetCorrection(type: OffsetCorrectionType,
                              ruuviTag: RuuviTagSensor,
                              sensorSettings: SensorSettings?) {
        let factory = StoryboardFactory(storyboardName: "OffsetCorrection")
        try! transitionHandler
            .forStoryboard(factory: factory, to: OffsetCorrectionModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(type: type, ruuviTag: ruuviTag, sensorSettings: sensorSettings)
            })
    }
}
