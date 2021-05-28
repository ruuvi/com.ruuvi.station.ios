import Foundation
import RuuviService

class MenuTableConfigurator {
    func configure(view: MenuTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = MenuRouter()
        router.transitionHandler = view

        let presenter = MenuPresenter()
        presenter.alertPresenter = r.resolve(AlertPresenter.self)
        presenter.cloudSyncService = r.resolve(RuuviServiceCloudSync.self)
        presenter.networkPersistence = r.resolve(NetworkPersistence.self)
        presenter.keychainService = r.resolve(KeychainService.self)
        presenter.featureToggleService = r.resolve(FeatureToggleService.self)
        presenter.view = view
        presenter.router = router

        view.output = presenter
    }
}
