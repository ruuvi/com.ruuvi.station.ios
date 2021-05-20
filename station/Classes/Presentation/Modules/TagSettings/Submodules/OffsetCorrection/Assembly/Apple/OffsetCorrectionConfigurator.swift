import UIKit
import BTKit

class OffsetCorrectionConfigurator {
    func configure(view: OffsetCorrectionAppleViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = OffsetCorrectionRouter()
        router.transitionHandler = view

        let presenter = OffsetCorrectionPresenter()
        presenter.view = view
        presenter.router = router
        presenter.backgroundPersistence = r.resolve(BackgroundPersistence.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.ruuviTagReactor = r.resolve(RuuviTagReactor.self)
        presenter.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(Settings.self)

        view.measurementService = r.resolve(MeasurementsService.self)
        view.output = presenter
    }
}
