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

        // Create single instances of services (prevent CPU spikes)
        let services = createServices(resolver: resolver)

        // Create main presenter
        let mainPresenter = CardsMainPresenter(
            dataService: services.dataService,
            alertService: services.alertService,
            backgroundService: services.backgroundService,
            connectionService: services.connectionService,
            settings: services.settings
        )

        // Create tab view controllers
        let tabControllers = createTabViewControllers()

        // Wire up all connections BEFORE view lifecycle methods
        wireUpConnections(
            landingViewController: landingViewController,
            mainPresenter: mainPresenter,
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
        settings: RuuviLocalSettings
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

        let settings = resolver.resolve(RuuviLocalSettings.self)!

        return (
            dataService: dataService,
            alertService: alertService,
            backgroundService: backgroundService,
            connectionService: connectionService,
            settings: settings
        )
    }

    // MARK: - Tab View Controller Creation
    private func createTabViewControllers() -> [CardsMenuType: UIViewController] {
        return [
            .measurement: CardsMeasurementViewController(),
            .graph: CardsGraphViewController(),
            .alerts: CardsAlertsViewController(),
            .settings: CardsSettingsViewController()
        ]
    }

    // MARK: - Connection Wiring (Protocol-based)
    private func wireUpConnections(
        landingViewController: NewCardsLandingViewController,
        mainPresenter: CardsMainPresenter,
        tabControllers: [CardsMenuType: UIViewController]
    ) {
        // Wire landing view controller to main presenter
        landingViewController.output = mainPresenter
        mainPresenter.view = landingViewController

        // Setup tab controllers in landing view controller
        landingViewController.setupTabViewControllers(tabControllers)

        // Setup tab controllers in main presenter (for presenter creation)
        mainPresenter.setupTabControllers(tabControllers)
    }
}

// MARK: - Factory Extensions for Testing
extension NewCardsModuleFactoryImpl {

    /// Create a cards module with mock services for testing
    func createForTesting(
        mockDataService: RuuviTagDataService? = nil,
        mockAlertService: RuuviTagAlertService? = nil,
        mockBackgroundService: RuuviTagBackgroundService? = nil,
        mockConnectionService: RuuviTagConnectionService? = nil,
        mockSettings: RuuviLocalSettings? = nil
    ) -> UIViewController {

        let landingViewController = NewCardsLandingViewController()
        let resolver = AppAssembly.shared.assembler.resolver

        // Use mock services if provided, otherwise create real ones
        let services = mockDataService != nil || mockAlertService != nil || mockBackgroundService != nil || mockConnectionService != nil || mockSettings != nil
            ? (
                dataService: mockDataService ?? createDataService(resolver: resolver),
                alertService: mockAlertService ?? createAlertService(resolver: resolver),
                backgroundService: mockBackgroundService ?? createBackgroundService(resolver: resolver),
                connectionService: mockConnectionService ?? createConnectionService(resolver: resolver),
                settings: mockSettings ?? resolver.resolve(RuuviLocalSettings.self)!
            )
            : createServices(resolver: resolver)

        let mainPresenter = CardsMainPresenter(
            dataService: services.dataService,
            alertService: services.alertService,
            backgroundService: services.backgroundService,
            connectionService: services.connectionService,
            settings: services.settings
        )

        let tabControllers = createTabViewControllers()

        wireUpConnections(
            landingViewController: landingViewController,
            mainPresenter: mainPresenter,
            tabControllers: tabControllers
        )

        return landingViewController
    }

    /// Create only specific tab view controllers for testing individual tabs
    func createTab(
        _ tab: CardsMenuType,
        // swiftlint:disable:next large_tuple
        with services: (
            dataService: RuuviTagDataService,
            alertService: RuuviTagAlertService,
            backgroundService: RuuviTagBackgroundService,
            connectionService: RuuviTagConnectionService,
            settings: RuuviLocalSettings
        )? = nil
    ) -> UIViewController {

        let resolver = AppAssembly.shared.assembler.resolver
        let actualServices = services ?? createServices(resolver: resolver)

        switch tab {
        case .measurement:
            let viewController = CardsMeasurementViewController()
            let presenter = CardsMeasurementPresenter(
                dataService: actualServices.dataService,
                alertService: actualServices.alertService,
                settings: actualServices.settings
            )

            presenter.view = viewController
            viewController.output = presenter

            return viewController

        case .graph:
            let viewController = CardsGraphViewController()
            let presenter = CardsGraphPresenter(
                dataService: actualServices.dataService,
                settings: actualServices.settings
            )

            presenter.view = viewController
            viewController.output = presenter

            return viewController

        case .alerts:
            let viewController = CardsAlertsViewController()
            let presenter = CardsAlertsPresenter(
                alertService: actualServices.alertService,
                settings: actualServices.settings
            )

            presenter.view = viewController
            viewController.output = presenter

            return viewController

        case .settings:
            let viewController = CardsSettingsViewController()
            let presenter = CardsSettingsPresenter(
                dataService: actualServices.dataService,
                settings: actualServices.settings
            )

            presenter.view = viewController
            viewController.output = presenter

            return viewController
        }
    }

    // MARK: - Individual Service Creation (for testing)
    private func createDataService(resolver: Resolver) -> RuuviTagDataService {
        return RuuviTagDataService(
            ruuviReactor: resolver.resolve(RuuviReactor.self)!,
            ruuviStorage: resolver.resolve(RuuviStorage.self)!,
            measurementService: resolver.resolve(RuuviServiceMeasurement.self)!,
            ruuviSensorPropertiesService: resolver.resolve(RuuviServiceSensorProperties.self)!,
            settings: resolver.resolve(RuuviLocalSettings.self)!,
            flags: resolver.resolve(RuuviLocalFlags.self)!
        )
    }

    private func createAlertService(resolver: Resolver) -> RuuviTagAlertService {
        return RuuviTagAlertService(
            alertService: resolver.resolve(RuuviServiceAlert.self)!,
            alertHandler: resolver.resolve(RuuviNotifier.self)!,
            settings: resolver.resolve(RuuviLocalSettings.self)!
        )
    }

    private func createBackgroundService(resolver: Resolver) -> RuuviTagBackgroundService {
        return RuuviTagBackgroundService(
            ruuviSensorPropertiesService: resolver.resolve(RuuviServiceSensorProperties.self)!
        )
    }

    private func createConnectionService(resolver: Resolver) -> RuuviTagConnectionService {
        return RuuviTagConnectionService(
            foreground: resolver.resolve(BTForeground.self)!,
            background: resolver.resolve(BTBackground.self)!,
            connectionPersistence: resolver.resolve(RuuviLocalConnections.self)!,
            localSyncState: resolver.resolve(RuuviLocalSyncState.self)!
        )
    }
}

//// MARK: - Service Builder Helper
//struct CardsServiceBuilder {
//    let resolver: Resolver
//
//    init(resolver: Resolver) {
//        self.resolver = resolver
//    }
//
//    func buildServices() -> (
//        dataService: RuuviTagDataService,
//        alertService: RuuviTagAlertService,
//        backgroundService: RuuviTagBackgroundService,
//        connectionService: RuuviTagConnectionService,
//        settings: RuuviLocalSettings
//    ) {
//        let factory = NewCardsModuleFactoryImpl()
//        return factory.createServices(resolver: resolver)
//    }
//}

// MARK: - Factory Configuration
extension NewCardsModuleFactoryImpl {

    /// Configure the module with specific options
    func create(with configuration: CardsModuleConfiguration) -> UIViewController {
        let landingViewController = NewCardsLandingViewController()
        let resolver = AppAssembly.shared.assembler.resolver

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
            settings: services.settings
        )

        // Create only enabled tabs
        let tabControllers = createTabViewControllers(enabledTabs: configuration.enabledTabs)

        wireUpConnections(
            landingViewController: landingViewController,
            mainPresenter: mainPresenter,
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
