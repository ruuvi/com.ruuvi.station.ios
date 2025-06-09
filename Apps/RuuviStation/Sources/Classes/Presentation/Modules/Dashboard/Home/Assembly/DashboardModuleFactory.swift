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
import Swinject
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

        // Create services for refactored architecture
        let sensorDataService = createSensorDataService(resolver: r)
        let alertManagementService = createAlertManagementService(resolver: r)
        let cloudSyncService = createCloudSyncService(resolver: r)
        let connectionService = createConnectionService(resolver: r)
        let settingsObservationService = createSettingsObservationService(resolver: r)
        let viewModelManagementService = createViewModelManagementService(resolver: r)
        let daemonErrorService = createDaemonErrorService(resolver: r)
        let universalLinkService = createUniversalLinkService(resolver: r)

        // Create service coordinator
        let serviceCoordinator = DashboardServiceCoordinator(
            sensorDataService: sensorDataService,
            alertManagementService: alertManagementService,
            cloudSyncService: cloudSyncService,
            connectionService: connectionService,
            settingsObservationService: settingsObservationService,
            viewModelManagementService: viewModelManagementService,
            daemonErrorService: daemonErrorService,
            universalLinkService: universalLinkService
        )

        // Use refactored presenter
        let presenter = DashboardPresenterRefactored()
        presenter.router = router
        presenter.view = view
        presenter.serviceCoordinator = serviceCoordinator
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.pushNotificationsManager = r.resolve(RuuviCorePN.self)
        presenter.permissionsManager = r.resolve(RuuviCorePermission.self)
        presenter.mailComposerPresenter = r.resolve(MailComposerPresenter.self)
        presenter.feedbackEmail = PresentationConstants.feedbackEmail
        presenter.feedbackSubject = PresentationConstants.feedbackSubject
        presenter.infoProvider = r.resolve(InfoProvider.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.ruuviSensorPropertiesService = r.resolve(RuuviServiceSensorProperties.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
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
        let menu = UIStoryboard(
            name: "Menu",
            bundle: .main
        )
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
        presenter.start()

        return view
    }

    // MARK: - Service Creation Methods
    private func createSensorDataService(resolver: Resolver) -> SensorDataServiceProtocol {
        return SensorDataService(
            ruuviReactor: resolver.resolve(RuuviReactor.self)!,
            ruuviStorage: resolver.resolve(RuuviStorage.self)!,
            ruuviSensorPropertiesService: resolver.resolve(RuuviServiceSensorProperties.self)!
        )
    }

    private func createAlertManagementService(resolver: Resolver) -> AlertManagementServiceProtocol {
        return AlertManagementService(
            alertService: resolver.resolve(RuuviServiceAlert.self)!,
            alertHandler: resolver.resolve(RuuviNotifier.self)!
        )
    }

    private func createCloudSyncService(resolver: Resolver) -> CloudSyncServiceProtocol {
        return CloudSyncService(
            cloudSyncDaemon: resolver.resolve(RuuviDaemonCloudSync.self)!,
            cloudSyncService: resolver.resolve(RuuviServiceCloudSync.self)!,
            localSyncState: resolver.resolve(RuuviLocalSyncState.self)!,
            ruuviUser: resolver.resolve(RuuviUser.self)!,
            settings: resolver.resolve(RuuviLocalSettings.self)!
        )
    }

    private func createConnectionService(resolver: Resolver) -> ConnectionServiceProtocol {
        return ConnectionService(
            background: resolver.resolve(BTBackground.self)!,
            foreground: resolver.resolve(BTForeground.self)!,
            connectionPersistence: resolver.resolve(RuuviLocalConnections.self)!
        )
    }

    private func createSettingsObservationService(resolver: Resolver) -> SettingsObservationServiceProtocol {
        return SettingsObservationService(
            settings: resolver.resolve(RuuviLocalSettings.self)!,
            ruuviAppSettingsService: resolver.resolve(RuuviServiceAppSettings.self)!
        )
    }

    private func createViewModelManagementService(resolver: Resolver) -> ViewModelManagementServiceProtocol {
        return ViewModelManagementService(
            settings: resolver.resolve(RuuviLocalSettings.self)!,
            ruuviUser: resolver.resolve(RuuviUser.self)!,
            sensorDataService: createSensorDataService(resolver: resolver)
        )
    }
    
    private func createDaemonErrorService(resolver: Resolver) -> DaemonErrorServiceProtocol {
        return DaemonErrorService()
    }
    
    private func createUniversalLinkService(resolver: Resolver) -> UniversalLinkServiceProtocol {
        return UniversalLinkService(
            ruuviUser: resolver.resolve(RuuviUser.self)!
        )
    }
}
