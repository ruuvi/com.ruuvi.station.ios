import UIKit
import BTKit

class DashboardScrollConfigurator {
    func configure(view: DashboardScrollViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = DashboardRouter()
        router.transitionHandler = view
        router.settings = r.resolve(Settings.self)
        
        let presenter = DashboardPresenter()
        presenter.router = router
        presenter.view = view
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(Settings.self)
        presenter.backgroundPersistence = r.resolve(BackgroundPersistence.self)
        presenter.scanner = r.resolve(BTScanner.self)
        presenter.webTagService = r.resolve(WebTagService.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.pushNotificationsManager = r.resolve(PushNotificationsManager.self)
        
        let menu = UIStoryboard(name: "Menu", bundle: .main).instantiateInitialViewController() as! UINavigationController
        menu.modalPresentationStyle = .custom
        let menuTable = menu.topViewController as! MenuTableViewController
        let menuPresenter = menuTable.output as! MenuPresenter
        menuPresenter.configure(output: presenter)
        
        let manager = MenuTableTransitionManager(container: view, menu: menu)
        let transition = MenuTableTransitioningDelegate(manager: manager)
        router.menuTableInteractiveTransition = transition
        menu.transitioningDelegate = transition
        
        view.menuPresentInteractiveTransition = transition.present
        view.menuDismissInteractiveTransition = transition.dismiss
        
        
        view.output = presenter
    }
}
