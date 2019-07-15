import Foundation
import BTKit

class HumidityCalibrationConfigurator {
    func configure(view: HumidityCalibrationViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = HumidityCalibrationRouter()
        router.transitionHandler = view
        
        let presenter = HumidityCalibrationPresenter()
        presenter.view = view
        presenter.router = router
        presenter.calibrationService = r.resolve(CalibrationService.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.scanner = r.resolve(BTScanner.self)
        
        view.output = presenter
    }
}
