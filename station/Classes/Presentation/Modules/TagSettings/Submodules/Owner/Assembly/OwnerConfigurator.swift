import Foundation
import RuuviService

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
        
        view.output = presenter
    }
}
