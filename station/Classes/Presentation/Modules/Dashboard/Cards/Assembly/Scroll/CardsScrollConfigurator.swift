import UIKit
import BTKit
import RuuviContext
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviVirtual
import RuuviCore
import RuuviNotifier

class CardsScrollConfigurator {
    // swiftlint:disable:next function_body_length
    func configure(view: CardsScrollViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = CardsRouter()
        router.transitionHandler = view
        router.settings = r.resolve(RuuviLocalSettings.self)

        let presenter = CardsPresenter()
        presenter.router = router
        presenter.view = view
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.webTagService = r.resolve(VirtualService.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.pushNotificationsManager = r.resolve(RuuviCorePN.self)
        presenter.permissionsManager = r.resolve(RuuviCorePermission.self)
        presenter.connectionPersistence = r.resolve(RuuviLocalConnections.self)
        presenter.alertService = r.resolve(RuuviServiceAlert.self)
        presenter.alertHandler = r.resolve(RuuviServiceNotifier.self)
        presenter.mailComposerPresenter = r.resolve(MailComposerPresenter.self)
        presenter.feedbackEmail = r.property("Feedback Email")!
        presenter.feedbackSubject = r.property("Feedback Subject")!
        presenter.infoProvider = r.resolve(InfoProvider.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.virtualReactor = r.resolve(VirtualReactor.self)
        presenter.measurementService = r.resolve(MeasurementsService.self)
        presenter.localSyncState = r.resolve(RuuviLocalSyncState.self)
        presenter.ruuviSensorPropertiesService = r.resolve(RuuviServiceSensorProperties.self)
        router.delegate = presenter

        // swiftlint:disable force_cast
        let menu = UIStoryboard(name: "Menu",
                                bundle: .main)
                                .instantiateInitialViewController() as! UINavigationController
        menu.modalPresentationStyle = .custom
        let menuTable = menu.topViewController as! MenuTableViewController
        let menuPresenter = menuTable.output as! MenuPresenter
        // swiftlint:enable force_cast
        menuPresenter.configure(output: presenter)

        let menuManager = MenuTableTransitionManager(container: view, menu: menu)
        let menuTransition = MenuTableTransitioningDelegate(manager: menuManager)
        router.menuTableInteractiveTransition = menuTransition
        menu.transitioningDelegate = menuTransition

        view.menuPresentInteractiveTransition = menuTransition.present
        view.menuDismissInteractiveTransition = menuTransition.dismiss

        // swiftlint:disable force_cast
        let tagCharts = UIStoryboard(name: "TagCharts",
                                     bundle: .main)
                                    .instantiateInitialViewController() as! TagChartsScrollViewController
        tagCharts.modalPresentationStyle = .custom
        let tagChartsPresenter = tagCharts.output as! TagChartsModuleInput
        // swiftlint:enable force_cast
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
        view.measurementService = r.resolve(MeasurementsService.self)

        view.output = presenter
    }
}
