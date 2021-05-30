import Foundation
import RuuviCloud
import RuuviService

class SignInConfigurator {
    func configure(view: SignInViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = SignInRouter()
        let presenter = SignInPresenter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router

        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.keychainService = r.resolve(KeychainService.self)
        presenter.ruuviCloud = r.resolve(RuuviCloud.self)
        presenter.cloudSyncService = r.resolve(RuuviServiceCloudSync.self)

        view.output = presenter
    }
}
