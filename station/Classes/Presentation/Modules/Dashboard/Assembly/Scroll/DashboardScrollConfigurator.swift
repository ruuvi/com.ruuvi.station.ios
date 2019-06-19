import UIKit

class DashboardScrollConfigurator {
    func configure(view: DashboardScrollViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = DashboardRouter()
        router.transitionHandler = view
        
        
        let presenter = DashboardPresenter()
        presenter.router = router
        presenter.view = view
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(Settings.self)
        presenter.backgroundPersistence = r.resolve(BackgroundPersistence.self)
        presenter.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
        
        let menu = UIStoryboard(name: "Menu", bundle: .main).instantiateInitialViewController() as! UINavigationController
        menu.modalPresentationStyle = .custom
        let menuTable = menu.topViewController as! MenuTableViewController
        let menuPresenter = menuTable.output as! MenuPresenter
        menuPresenter.configure(output: presenter)
        
        let manager = MenuTableTransitionManager(container: view, menu: menu)
        router.menuTableTransition = MenuTableTransitioningDelegate(manager: manager)
        
        let transition = MenuTableTransitioningDelegate(manager: manager)
        router.menuTableInteractiveTransition = transition
        menu.transitioningDelegate = transition
        
        view.menuPresentInteractiveTransition = transition.present
        view.menuDismissInteractiveTransition = transition.dismiss
        
        
        view.output = presenter
    }
}
