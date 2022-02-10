import UIKit
import BTKit
import RuuviService
import RuuviReactor
import RuuviLocal
import RuuviStorage
import RuuviPresenters

class OffsetCorrectionConfigurator {
    func configure(view: OffsetCorrectionAppleViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = OffsetCorrectionRouter()
        router.transitionHandler = view

        let presenter = OffsetCorrectionPresenter()
        presenter.view = view
        presenter.router = router
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.ruuviOffsetCalibrationService = r.resolve(RuuviServiceOffsetCalibration.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)

        view.measurementService = r.resolve(RuuviServiceMeasurement.self)
        view.output = presenter
    }
}
