import UIKit
import BTKit
import RuuviStorage
import RuuviReactor
import RuuviLocal

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
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)

        view.measurementService = r.resolve(MeasurementsService.self)
        view.output = presenter
    }
}
