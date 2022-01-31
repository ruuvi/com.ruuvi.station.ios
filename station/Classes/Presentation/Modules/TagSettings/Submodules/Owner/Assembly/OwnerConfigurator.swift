import Foundation
import RuuviService
import RuuviPool
import RuuviStorage

final class OwnerConfigurator {
    func configure(view: OwnerViewController) {
        let r = AppAssembly.shared.assembler.resolver
        let router = OwnerRouter()
        router.transitionHandler = view

        let presenter = OwnerPresenter()
        presenter.view = view
        presenter.router = router
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.ruuviOwnershipService = r.resolve(RuuviServiceOwnership.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.ruuviPool = r.resolve(RuuviPool.self)

        view.output = presenter
    }
}
