import Foundation
import RuuviLocal
import RuuviPool
import RuuviPresenters
import RuuviService
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
        presenter.featureToggleService = r.resolve(FeatureToggleService.self)
        presenter.connectionPersistence = r.resolve(RuuviLocalConnections.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)

        view.output = presenter
    }
}
