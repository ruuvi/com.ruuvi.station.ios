import UIKit
import BTKit

class CardsScrollConfigurator {
    func configure(view: CardsScrollViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = CardsRouter()
        router.transitionHandler = view
        router.settings = r.resolve(Settings.self)
        
        let presenter = CardsPresenter()
        presenter.router = router
        presenter.view = view
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(Settings.self)
        presenter.backgroundPersistence = r.resolve(BackgroundPersistence.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.webTagService = r.resolve(WebTagService.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.pushNotificationsManager = r.resolve(PushNotificationsManager.self)
        presenter.permissionsManager = r.resolve(PermissionsManager.self)
        presenter.connectionPersistence = r.resolve(ConnectionPersistence.self)
        
        router.delegate = presenter
        
        let menu = UIStoryboard(name: "Menu", bundle: .main).instantiateInitialViewController() as! UINavigationController
        menu.modalPresentationStyle = .custom
        let menuTable = menu.topViewController as! MenuTableViewController
        let menuPresenter = menuTable.output as! MenuPresenter
        menuPresenter.configure(output: presenter)
        
        let menuManager = MenuTableTransitionManager(container: view, menu: menu)
        let menuTransition = MenuTableTransitioningDelegate(manager: menuManager)
        router.menuTableInteractiveTransition = menuTransition
        menu.transitioningDelegate = menuTransition
        
        view.menuPresentInteractiveTransition = menuTransition.present
        view.menuDismissInteractiveTransition = menuTransition.dismiss
        
        let tagCharts = UIStoryboard(name: "TagCharts", bundle: .main).instantiateInitialViewController() as! TagChartsScrollViewController
        tagCharts.modalPresentationStyle = .custom
        let tagChartsPresenter = tagCharts.output as! TagChartsModuleInput
        tagChartsPresenter.configure(output: presenter)
        presenter.tagCharts = tagChartsPresenter
        
        let chartsManager = TagChartsTransitionManager(container: view, charts: tagCharts)
        let chartsTransition = TagChartsTransitioningDelegate(manager: chartsManager)
        router.tagChartsTransitioningDelegate = chartsTransition
        tagCharts.transitioningDelegate = chartsTransition
        
        tagCharts.tagChartsDismissInteractiveTransition = chartsTransition.dismiss
        
        router.tagCharts = tagCharts
        
        view.tagChartsPresentInteractiveTransition = chartsTransition.present
        view.tagChartsDismissInteractiveTransition = chartsTransition.dismiss
        
        view.output = presenter
    }
}
