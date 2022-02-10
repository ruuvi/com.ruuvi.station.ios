import Foundation
import RuuviCloud
import RuuviService
import RuuviUser
import RuuviPresenters
import RuuviDaemon

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
        presenter.ruuviUser = r.resolve(RuuviUser.self)
        presenter.ruuviCloud = r.resolve(RuuviCloud.self)
        presenter.cloudSyncService = r.resolve(RuuviServiceCloudSync.self)
        presenter.cloudSyncDaemon = r.resolve(RuuviDaemonCloudSync.self)

        view.output = presenter
    }
}
