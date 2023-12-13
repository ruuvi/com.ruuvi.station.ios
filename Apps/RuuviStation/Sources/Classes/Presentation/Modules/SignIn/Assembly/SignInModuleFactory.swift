import Foundation
import RuuviCloud
import RuuviDaemon
import RuuviLocal
import RuuviPresenters
import RuuviService
import RuuviUser

protocol SignInModuleFactory: AnyObject {
    func create() -> SignInViewController
}

class SignInModuleFactoryImpl: SignInModuleFactory {
    func create() -> SignInViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = SignInViewController()
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
        presenter.cloudNotificationService = r.resolve(RuuviServiceCloudNotification.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)

        view.output = presenter
        return view
    }
}
