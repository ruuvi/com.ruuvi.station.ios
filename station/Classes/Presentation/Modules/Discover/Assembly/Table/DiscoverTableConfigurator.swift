import Foundation
import BTKit

class DiscoverTableConfigurator {
    func configure(view: DiscoverTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = DiscoverRouter()
        router.transitionHandler = view

        let presenter = DiscoverPresenter()
        presenter.view = view
        presenter.router = router
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.webTagService = r.resolve(WebTagService.self)
        presenter.permissionsManager = r.resolve(PermissionsManager.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.keychainService = r.resolve(KeychainService.self)
        presenter.ruuviNetworkKaltiot = r.resolve(RuuviNetworkKaltiot.self)
        presenter.ruuviTagTank = r.resolve(RuuviTagTank.self)
        presenter.ruuviTagReactor = r.resolve(RuuviTagReactor.self)
        presenter.settings = r.resolve(Settings.self)

        view.output = presenter
    }
}
