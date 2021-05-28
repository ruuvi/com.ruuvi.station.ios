import UIKit
import BTKit
import RuuviStorage

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
        presenter.ruuviTagReactor = r.resolve(RuuviTagReactor.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(Settings.self)

        view.measurementService = r.resolve(MeasurementsService.self)
        view.output = presenter
    }
}
