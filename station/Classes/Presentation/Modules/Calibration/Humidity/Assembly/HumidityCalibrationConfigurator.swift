import Foundation

class HumidityCalibrationConfigurator {
    func configure(view: HumidityCalibrationViewController) {
        let router = HumidityCalibrationRouter()
        router.transitionHandler = view
        
        let presenter = HumidityCalibrationPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
