import BTKit
import RuuviContext
import RuuviCore
import RuuviDaemon
import RuuviLocal
import RuuviNotifier
import RuuviPool
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage
import RuuviUser
import UIKit

protocol DashboardModuleFactory {
    func create() -> UIViewController
}

final class DashboardModuleFactoryImpl: DashboardModuleFactory {
    // swiftlint:disable:next function_body_length
    func create() -> UIViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = DashboardViewController()
        let router = DashboardRouter()
        router.transitionHandler = view
        router.settings = r.resolve(RuuviLocalSettings.self)

        let presenter = DashboardPresenter()
        presenter.router = router
        presenter.view = view
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.pushNotificationsManager = r.resolve(RuuviCorePN.self)
        presenter.permissionsManager = r.resolve(RuuviCorePermission.self)
        presenter.connectionPersistence = r.resolve(RuuviLocalConnections.self)
        presenter.alertService = r.resolve(RuuviServiceAlert.self)
        presenter.alertHandler = r.resolve(RuuviNotifier.self)
        presenter.mailComposerPresenter = r.resolve(MailComposerPresenter.self)
        presenter.feedbackEmail = PresentationConstants.feedbackEmail
        presenter.feedbackSubject = PresentationConstants.feedbackSubject
        presenter.infoProvider = r.resolve(InfoProvider.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.measurementService = r.resolve(RuuviServiceMeasurement.self)
        presenter.localSyncState = r.resolve(RuuviLocalSyncState.self)
        presenter.ruuviSensorPropertiesService = r.resolve(RuuviServiceSensorProperties.self)
        presenter.ruuviUser = r.resolve(RuuviUser.self)
        presenter.featureToggleService = r.resolve(FeatureToggleService.self)
        presenter.cloudSyncDaemon = r.resolve(RuuviDaemonCloudSync.self)
        presenter.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.authService = r.resolve(RuuviServiceAuth.self)
        presenter.pnManager = r.resolve(RuuviCorePN.self)
        presenter.cloudNotificationService = r.resolve(RuuviServiceCloudNotification.self)
        router.delegate = presenter

        let interactor = DashboardInteractor()
        interactor.background = r.resolve(BTBackground.self)
        interactor.connectionPersistence = r.resolve(RuuviLocalConnections.self)
        interactor.ruuviPool = r.resolve(RuuviPool.self)
        interactor.ruuviOwnershipService = r.resolve(RuuviServiceOwnership.self)
        interactor.settings = r.resolve(RuuviLocalSettings.self)
        interactor.ruuviUser = r.resolve(RuuviUser.self)
        presenter.interactor = interactor

        // MARK: - MENU

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

        // MARK: VIEW

        view.measurementService = r.resolve(RuuviServiceMeasurement.self)

        view.output = presenter

        return view
    }
}
