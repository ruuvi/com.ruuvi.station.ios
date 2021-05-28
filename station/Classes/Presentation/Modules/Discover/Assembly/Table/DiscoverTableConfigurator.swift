import Foundation
import BTKit
import RuuviContext
import RuuviReactor
import RuuviLocal

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
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.webTagService = r.resolve(WebTagService.self)
        presenter.permissionsManager = r.resolve(PermissionsManager.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.ruuviTagTank = r.resolve(RuuviTagTank.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)

        view.output = presenter
    }
}
