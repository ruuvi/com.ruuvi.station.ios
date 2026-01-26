import Foundation
import RuuviPool
import RuuviPresenters
import RuuviReactor
import RuuviService

class ShareConfigurator {
    func configure(view: ShareViewController) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                buildModule(view: view)
            }
            return
        }
        DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                buildModule(view: view)
            }
        }
    }

    @MainActor
    private func buildModule(view: ShareViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = ShareRouter()
        let presenter = SharePresenter()
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.alertPresenter = r.resolve(AlertPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.ruuviOwnershipService = r.resolve(RuuviServiceOwnership.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.ruuviPool = r.resolve(RuuviPool.self)

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router

        view.output = presenter
    }
}
