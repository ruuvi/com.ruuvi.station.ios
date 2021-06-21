import Foundation
import BTKit
import RuuviContext
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviVirtual

class DiscoverTableConfigurator {
    func configure(view: DiscoverTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = DiscoverRouter()
        router.transitionHandler = view

        let presenter = DiscoverPresenter()
        presenter.view = view
        presenter.router = router
        presenter.virtualReactor = r.resolve(VirtualReactor.self)
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.virtualService = r.resolve(VirtualService.self)
        presenter.permissionsManager = r.resolve(PermissionsManager.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.ruuviOwnershipService = r.resolve(RuuviServiceOwnership.self)

        view.output = presenter
    }
}
