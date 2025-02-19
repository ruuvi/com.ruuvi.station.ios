import RuuviLocal
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage
import UIKit

class OffsetCorrectionConfigurator {
    func configure(view: OffsetCorrectionAppleViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = OffsetCorrectionRouter()
        router.transitionHandler = view

        let presenter = OffsetCorrectionPresenter()
        presenter.view = view
        presenter.router = router
        presenter.ruuviOffsetCalibrationService = r.resolve(RuuviServiceOffsetCalibration.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)

        view.measurementService = r.resolve(RuuviServiceMeasurement.self)
        view.output = presenter
    }
}
