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
import Swinject

protocol DashboardModuleFactory {
    func create() -> UIViewController
}

final class DashboardModuleFactoryImpl: DashboardModuleFactory {

    func create() -> UIViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = DashboardViewController()
        let router = DashboardRouter()
        router.transitionHandler = view
        router.settings = r.resolve(RuuviLocalSettings.self)

        // Create services using the factory
        let serviceFactory = DashboardServiceFactory.create(from: r)

        // Create the new service-based presenter
        let presenter = serviceFactory.createDashboardModule(
            router: router,
            errorPresenter: r.resolve(ErrorPresenter.self)!,
            permissionPresenter: r.resolve(PermissionPresenter.self)!,
            pushNotificationsManager: r.resolve(RuuviCorePN.self)!,
            mailComposerPresenter: r.resolve(MailComposerPresenter.self)!,
            feedbackEmail: PresentationConstants.feedbackEmail,
            feedbackSubject: PresentationConstants.feedbackSubject,
            infoProvider: r.resolve(InfoProvider.self)!,
            activityPresenter: r.resolve(ActivityPresenter.self)!
        )

        // Set up presenter dependencies
        presenter.view = view
        router.delegate = presenter

        // Create and configure interactor (if still needed)
        let interactor = DashboardInteractor()
        interactor.background = r.resolve(BTBackground.self)
        interactor.connectionPersistence = r.resolve(RuuviLocalConnections.self)
        interactor.ruuviPool = r.resolve(RuuviPool.self)
        interactor.ruuviOwnershipService = r.resolve(RuuviServiceOwnership.self)
        interactor.settings = r.resolve(RuuviLocalSettings.self)
        interactor.ruuviUser = r.resolve(RuuviUser.self)
        presenter.interactor = interactor

        // MARK: - MENU
        setupMenuModule(for: view, presenter: presenter, resolver: r, router: router)

        // MARK: - VIEW
        view.measurementService = r.resolve(RuuviServiceMeasurement.self)
        view.output = presenter

        return view
    }

    // MARK: - Private Helper Methods
    private func setupMenuModule(
        for view: DashboardViewController,
        presenter: DashboardPresenter,
        resolver: Resolver,
        router: DashboardRouter
    ) {
        // swiftlint:disable force_cast
        let menu = UIStoryboard(
            name: "Menu",
            bundle: .main
        ).instantiateInitialViewController() as! UINavigationController

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
    }
}

// MARK: - Legacy Support
extension DashboardModuleFactoryImpl {

    /// Creates module with additional configuration options
    func createWithConfiguration(
        customFeedbackEmail: String? = nil,
        customFeedbackSubject: String? = nil
    ) -> UIViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = DashboardViewController()
        let router = DashboardRouter()
        router.transitionHandler = view
        router.settings = r.resolve(RuuviLocalSettings.self)

        let serviceFactory = DashboardServiceFactory.create(from: r)

        let presenter = serviceFactory.createDashboardModule(
            router: router,
            errorPresenter: r.resolve(ErrorPresenter.self)!,
            permissionPresenter: r.resolve(PermissionPresenter.self)!,
            pushNotificationsManager: r.resolve(RuuviCorePN.self)!,
            mailComposerPresenter: r.resolve(MailComposerPresenter.self)!,
            feedbackEmail: customFeedbackEmail ?? PresentationConstants.feedbackEmail,
            feedbackSubject: customFeedbackSubject ?? PresentationConstants.feedbackSubject,
            infoProvider: r.resolve(InfoProvider.self)!,
            activityPresenter: r.resolve(ActivityPresenter.self)!
        )

        presenter.view = view
        router.delegate = presenter

        let interactor = DashboardInteractor()
        interactor.background = r.resolve(BTBackground.self)
        interactor.connectionPersistence = r.resolve(RuuviLocalConnections.self)
        interactor.ruuviPool = r.resolve(RuuviPool.self)
        interactor.ruuviOwnershipService = r.resolve(RuuviServiceOwnership.self)
        interactor.settings = r.resolve(RuuviLocalSettings.self)
        interactor.ruuviUser = r.resolve(RuuviUser.self)
        presenter.interactor = interactor

        setupMenuModule(for: view, presenter: presenter, resolver: r, router: router)

        view.measurementService = r.resolve(RuuviServiceMeasurement.self)
        view.output = presenter

        return view
    }
}

// MARK: - Service Access for Other Modules
extension DashboardModuleFactoryImpl {

    /// Creates individual services for use in other modules
    func createSensorDataService() -> RuuviTagDataService {
        let r = AppAssembly.shared.assembler.resolver
        let factory = DashboardServiceFactory.create(from: r)
        return factory.createSensorDataService()
    }

    func createAlertService() -> RuuviTagAlertService {
        let r = AppAssembly.shared.assembler.resolver
        let factory = DashboardServiceFactory.create(from: r)
        return factory.createAlertService()
    }

    func createBackgroundService() -> RuuviTagBackgroundService {
        let r = AppAssembly.shared.assembler.resolver
        let factory = DashboardServiceFactory.create(from: r)
        return factory.createBackgroundService()
    }

    func createConnectionService() -> RuuviTagConnectionService {
        let r = AppAssembly.shared.assembler.resolver
        let factory = DashboardServiceFactory.create(from: r)
        return factory.createConnectionService()
    }

    func createSettingsService() -> DashboardSettingsService {
        let r = AppAssembly.shared.assembler.resolver
        let factory = DashboardServiceFactory.create(from: r)
        return factory.createSettingsService()
    }

    func createCloudSyncService() -> DashboardCloudSyncService {
        let r = AppAssembly.shared.assembler.resolver
        let factory = DashboardServiceFactory.create(from: r)
        return factory.createCloudSyncService()
    }
}
