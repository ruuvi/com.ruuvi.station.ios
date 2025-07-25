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

protocol NewCardsModuleFactory {
    func create() -> NewCardsLandingViewController
}

final class NewCardsModuleFactoryImpl: NewCardsModuleFactory {
    func create() -> NewCardsLandingViewController {
        let resolver = AppAssembly.shared.assembler.resolver

        // Create the landing view controller (but don't trigger any setup yet)
        let landingViewController = NewCardsLandingViewController()

        let router = CardsRouter()

        // Create single instances of services
        let services = createServices(resolver: resolver)

        // Create main presenter
        let mainPresenter = CardsMainPresenter(
            dataService: services.dataService,
            alertService: services.alertService,
            backgroundService: services.backgroundService,
            connectionService: services.connectionService,
            dashboardCloudSyncService: services.dashboardCloudSyncService,
            settings: services.settings,
            flags: services.flags,
            router: router
        )

        // Create tab view controllers
        let tabControllers = createTabViewControllers()

        // Wire up all connections BEFORE view lifecycle methods
        wireUpConnections(
            landingViewController: landingViewController,
            mainPresenter: mainPresenter,
            router: router,
            flags: services.flags,
            tabControllers: tabControllers
        )

        return landingViewController
    }

    // MARK: - Service Creation (Single instances)
    // swiftlint:disable:next large_tuple
    private func createServices(resolver: Resolver) -> (
        dataService: RuuviTagDataService,
        alertService: RuuviTagAlertService,
        backgroundService: RuuviTagBackgroundService,
        connectionService: RuuviTagConnectionService,
        dashboardCloudSyncService: RuuviCloudService,
        settings: RuuviLocalSettings,
        flags: RuuviLocalFlags
    ) {

        let dataService = RuuviTagDataService(
            ruuviReactor: resolver.resolve(RuuviReactor.self)!,
            ruuviStorage: resolver.resolve(RuuviStorage.self)!,
            measurementService: resolver.resolve(RuuviServiceMeasurement.self)!,
            ruuviSensorPropertiesService: resolver.resolve(RuuviServiceSensorProperties.self)!,
            settings: resolver.resolve(RuuviLocalSettings.self)!,
            flags: resolver.resolve(RuuviLocalFlags.self)!
        )

        let alertService = RuuviTagAlertService(
            alertService: resolver.resolve(RuuviServiceAlert.self)!,
            alertHandler: resolver.resolve(RuuviNotifier.self)!,
            settings: resolver.resolve(RuuviLocalSettings.self)!
        )

        let backgroundService = RuuviTagBackgroundService(
            ruuviSensorPropertiesService: resolver.resolve(RuuviServiceSensorProperties.self)!
        )

        let connectionService = RuuviTagConnectionService(
            foreground: resolver.resolve(BTForeground.self)!,
            background: resolver.resolve(BTBackground.self)!,
            connectionPersistence: resolver.resolve(RuuviLocalConnections.self)!,
            localSyncState: resolver.resolve(RuuviLocalSyncState.self)!
        )

        let dashboardCloudSyncService = RuuviCloudService(
            cloudSyncDaemon: resolver.resolve(RuuviDaemonCloudSync.self)!,
            cloudSyncService: resolver.resolve(RuuviServiceCloudSync.self)!,
            cloudNotificationService: resolver.resolve(RuuviServiceCloudNotification.self)!,
            authService: resolver.resolve(RuuviServiceAuth.self)!,
            ruuviUser: resolver.resolve(RuuviUser.self)!,
            settings: resolver.resolve(RuuviLocalSettings.self)!,
            pnManager: resolver.resolve(RuuviCorePN.self)!
        )

        let settings = resolver.resolve(RuuviLocalSettings.self)!
        let flags = resolver.resolve(RuuviLocalFlags.self)!

        return (
            dataService: dataService,
            alertService: alertService,
            backgroundService: backgroundService,
            connectionService: connectionService,
            dashboardCloudSyncService: dashboardCloudSyncService,
            settings: settings,
            flags: flags
        )
    }

    // MARK: - Tab View Controller Creation
    private func createTabViewControllers() -> [CardsMenuType: UIViewController] {
        return [
            .measurement: CardsMeasurementViewController(),
            .graph: CardsGraphViewController(),
            .alerts: CardsAlertsViewController(),
            .settings: CardsSettingsViewController(),
        ]
    }

    // MARK: - Connection Wiring (Protocol-based)
    private func wireUpConnections(
        landingViewController: NewCardsLandingViewController,
        mainPresenter: CardsMainPresenter,
        router: CardsRouter,
        flags: RuuviLocalFlags,
        tabControllers: [CardsMenuType: UIViewController]
    ) {
        router.transitionHandler = landingViewController

        // Wire landing view controller to main presenter
        landingViewController.output = mainPresenter
        landingViewController.flags = flags
        mainPresenter.view = landingViewController

        // Setup tab controllers in landing view controller
        landingViewController.setupTabViewControllers(tabControllers)

        // Setup tab controllers in main presenter (for presenter creation)
        mainPresenter.setupTabControllers(tabControllers)
    }
}

// MARK: - Factory Configuration
extension NewCardsModuleFactoryImpl {

    /// Configure the module with specific options
    func create(with configuration: CardsModuleConfiguration) -> UIViewController {
        let landingViewController = NewCardsLandingViewController()
        let resolver = AppAssembly.shared.assembler.resolver

        // Create router for the cards page navigation
        let router = CardsRouter()

        // Create services with configuration
        let services = createServices(resolver: resolver)

        // Apply configuration
        if configuration.enableDebugMode {
            enableDebugLogging()
        }

        if configuration.enablePerformanceMonitoring {
            // Enable performance monitoring
            print("Performance monitoring enabled")
        }

        // Create main presenter with configuration
        let mainPresenter = CardsMainPresenter(
            dataService: services.dataService,
            alertService: services.alertService,
            backgroundService: services.backgroundService,
            connectionService: services.connectionService,
            dashboardCloudSyncService: services.dashboardCloudSyncService,
            settings: services.settings,
            flags: services.flags,
            router: router
        )

        // Create only enabled tabs
        let tabControllers = createTabViewControllers(enabledTabs: configuration.enabledTabs)

        wireUpConnections(
            landingViewController: landingViewController,
            mainPresenter: mainPresenter,
            router: router,
            flags: services.flags,
            tabControllers: tabControllers
        )

        return landingViewController
    }

    private func createTabViewControllers(enabledTabs: Set<CardsMenuType>) -> [CardsMenuType: UIViewController] {
        var controllers: [CardsMenuType: UIViewController] = [:]

        for tab in enabledTabs {
            switch tab {
            case .measurement:
                controllers[.measurement] = CardsMeasurementViewController()
            case .graph:
                controllers[.graph] = CardsGraphViewController()
            case .alerts:
                controllers[.alerts] = CardsAlertsViewController()
            case .settings:
                controllers[.settings] = CardsSettingsViewController()
            }
        }

        return controllers
    }

    private func enableDebugLogging() {
        print("Debug logging enabled for Cards module")
        // Enable debug logging for all services
        // This could include:
        // - Service lifecycle events
        // - Data flow between services
        // - Performance metrics
        // - Error details
    }
}

// MARK: - Configuration Object
struct CardsModuleConfiguration {
    let enabledTabs: Set<CardsMenuType>
    let enableDebugMode: Bool
    let enablePerformanceMonitoring: Bool
    let updateThrottleInterval: TimeInterval

    static let `default` = CardsModuleConfiguration(
        enabledTabs: Set(CardsMenuType.allCases),
        enableDebugMode: false,
        enablePerformanceMonitoring: false,
        updateThrottleInterval: 0.2
    )

    static let debug = CardsModuleConfiguration(
        enabledTabs: Set(CardsMenuType.allCases),
        enableDebugMode: true,
        enablePerformanceMonitoring: true,
        updateThrottleInterval: 0.1
    )

    static let measurementOnly = CardsModuleConfiguration(
        enabledTabs: [.measurement],
        enableDebugMode: false,
        enablePerformanceMonitoring: false,
        updateThrottleInterval: 0.2
    )

    static let performanceOptimized = CardsModuleConfiguration(
        enabledTabs: Set(CardsMenuType.allCases),
        enableDebugMode: false,
        enablePerformanceMonitoring: false,
        updateThrottleInterval: 0.3 // Slower updates for better performance
    )
}
