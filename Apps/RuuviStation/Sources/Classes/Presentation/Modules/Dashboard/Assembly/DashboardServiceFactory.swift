import UIKit
import Swinject
import BTKit
import RuuviOntology
import RuuviReactor
import RuuviStorage
import RuuviService
import RuuviLocal
import RuuviCore
import RuuviDaemon
import RuuviUser
import RuuviNotifier
import RuuviPresenters

/// Factory class responsible for creating and configuring all dashboard services
class DashboardServiceFactory {

    // MARK: - Dependencies (injected from app assembly)
    private let ruuviReactor: RuuviReactor
    private let ruuviStorage: RuuviStorage
    private let measurementService: RuuviServiceMeasurement
    private let settings: RuuviLocalSettings
    private let flags: RuuviLocalFlags
    private let alertService: RuuviServiceAlert
    private let alertHandler: RuuviNotifier
    private let ruuviSensorPropertiesService: RuuviServiceSensorProperties
    private let foreground: BTForeground
    private let background: BTBackground
    private let connectionPersistence: RuuviLocalConnections
    private let localSyncState: RuuviLocalSyncState
    private let ruuviAppSettingsService: RuuviServiceAppSettings
    private let cloudSyncDaemon: RuuviDaemonCloudSync
    private let cloudSyncService: RuuviServiceCloudSync
    private let cloudNotificationService: RuuviServiceCloudNotification
    private let authService: RuuviServiceAuth
    private let ruuviUser: RuuviUser
    private let pnManager: RuuviCorePN

    // MARK: - Initialization
    init(
        ruuviReactor: RuuviReactor,
        ruuviStorage: RuuviStorage,
        measurementService: RuuviServiceMeasurement,
        settings: RuuviLocalSettings,
        flags: RuuviLocalFlags,
        alertService: RuuviServiceAlert,
        alertHandler: RuuviNotifier,
        ruuviSensorPropertiesService: RuuviServiceSensorProperties,
        foreground: BTForeground,
        background: BTBackground,
        connectionPersistence: RuuviLocalConnections,
        localSyncState: RuuviLocalSyncState,
        ruuviAppSettingsService: RuuviServiceAppSettings,
        cloudSyncDaemon: RuuviDaemonCloudSync,
        cloudSyncService: RuuviServiceCloudSync,
        cloudNotificationService: RuuviServiceCloudNotification,
        authService: RuuviServiceAuth,
        ruuviUser: RuuviUser,
        pnManager: RuuviCorePN
    ) {
        self.ruuviReactor = ruuviReactor
        self.ruuviStorage = ruuviStorage
        self.measurementService = measurementService
        self.settings = settings
        self.flags = flags
        self.alertService = alertService
        self.alertHandler = alertHandler
        self.ruuviSensorPropertiesService = ruuviSensorPropertiesService
        self.foreground = foreground
        self.background = background
        self.connectionPersistence = connectionPersistence
        self.localSyncState = localSyncState
        self.ruuviAppSettingsService = ruuviAppSettingsService
        self.cloudSyncDaemon = cloudSyncDaemon
        self.cloudSyncService = cloudSyncService
        self.cloudNotificationService = cloudNotificationService
        self.authService = authService
        self.ruuviUser = ruuviUser
        self.pnManager = pnManager
    }

    // MARK: - Service Creation
    func createSensorDataService() -> RuuviTagDataService {
        return RuuviTagDataService(
            ruuviReactor: ruuviReactor,
            ruuviStorage: ruuviStorage,
            measurementService: measurementService,
            ruuviSensorPropertiesService: ruuviSensorPropertiesService,
            settings: settings,
            flags: flags
        )
    }

    func createAlertService() -> RuuviTagAlertService {
        return RuuviTagAlertService(
            alertService: alertService,
            alertHandler: alertHandler,
            settings: settings
        )
    }

    func createConnectionService() -> RuuviTagConnectionService {
        return RuuviTagConnectionService(
            foreground: foreground,
            background: background,
            connectionPersistence: connectionPersistence,
            localSyncState: localSyncState
        )
    }

    func createSettingsService() -> DashboardSettingsService {
        return DashboardSettingsService(
            settings: settings,
            ruuviAppSettingsService: ruuviAppSettingsService
        )
    }

    func createCloudSyncService() -> RuuviCloudService {
        return RuuviCloudService(
            cloudSyncDaemon: cloudSyncDaemon,
            cloudSyncService: cloudSyncService,
            cloudNotificationService: cloudNotificationService,
            authService: authService,
            ruuviUser: ruuviUser,
            settings: settings,
            pnManager: pnManager
        )
    }

    // MARK: - Complete Presenter Creation
    func createDashboardPresenter() -> DashboardPresenter {
        let sensorDataService = createSensorDataService()
        let alertService = createAlertService()
        let connectionService = createConnectionService()
        let settingsService = createSettingsService()
        let cloudSyncService = createCloudSyncService()

        return DashboardPresenter(
            sensorDataService: sensorDataService,
            alertService: alertService,
            connectionService: connectionService,
            settingsService: settingsService,
            cloudSyncService: cloudSyncService
        )
    }
}

// MARK: - Assembly Integration
extension DashboardServiceFactory {

    /// Creates the factory from Swinject resolver
    static func create(from resolver: Resolver) -> DashboardServiceFactory {
        return DashboardServiceFactory(
            ruuviReactor: resolver.resolve(RuuviReactor.self)!,
            ruuviStorage: resolver.resolve(RuuviStorage.self)!,
            measurementService: resolver.resolve(RuuviServiceMeasurement.self)!,
            settings: resolver.resolve(RuuviLocalSettings.self)!,
            flags: resolver.resolve(RuuviLocalFlags.self)!,
            alertService: resolver.resolve(RuuviServiceAlert.self)!,
            alertHandler: resolver.resolve(RuuviNotifier.self)!,
            ruuviSensorPropertiesService: resolver.resolve(RuuviServiceSensorProperties.self)!,
            foreground: resolver.resolve(BTForeground.self)!,
            background: resolver.resolve(BTBackground.self)!,
            connectionPersistence: resolver.resolve(RuuviLocalConnections.self)!,
            localSyncState: resolver.resolve(RuuviLocalSyncState.self)!,
            ruuviAppSettingsService: resolver.resolve(RuuviServiceAppSettings.self)!,
            cloudSyncDaemon: resolver.resolve(RuuviDaemonCloudSync.self)!,
            cloudSyncService: resolver.resolve(RuuviServiceCloudSync.self)!,
            cloudNotificationService: resolver.resolve(RuuviServiceCloudNotification.self)!,
            authService: resolver.resolve(RuuviServiceAuth.self)!,
            ruuviUser: resolver.resolve(RuuviUser.self)!,
            pnManager: resolver.resolve(RuuviCorePN.self)!
        )
    }

    /// Creates the factory from AppAssembly (legacy support)
    static func create(from appAssembly: AppAssembly) -> DashboardServiceFactory {
        return create(from: appAssembly.assembler.resolver)
    }
}

// MARK: - Service Management
extension DashboardServiceFactory {

    // swiftlint:disable:next function_parameter_count
    func createDashboardModule(
        router: DashboardRouterInput,
        errorPresenter: ErrorPresenter,
        permissionPresenter: PermissionPresenter,
        pushNotificationsManager: RuuviCorePN,
        mailComposerPresenter: MailComposerPresenter,
        feedbackEmail: String,
        feedbackSubject: String,
        infoProvider: InfoProvider,
        activityPresenter: ActivityPresenter,
        flags: RuuviLocalFlags
    ) -> DashboardPresenter {

        let presenter = createDashboardPresenter()

        // Inject additional dependencies
        presenter.router = router
        presenter.errorPresenter = errorPresenter
        presenter.permissionPresenter = permissionPresenter
        presenter.pushNotificationsManager = pushNotificationsManager
        presenter.mailComposerPresenter = mailComposerPresenter
        presenter.feedbackEmail = feedbackEmail
        presenter.feedbackSubject = feedbackSubject
        presenter.infoProvider = infoProvider
        presenter.activityPresenter = activityPresenter
        presenter.flags = flags

        return presenter
    }
}

// MARK: - Service Configuration
extension DashboardServiceFactory {

    // swiftlint:disable:next orphaned_doc_comment
    /// Creates services with shared caching for better performance
    // swiftlint:disable:next large_tuple
    func createServicesWithSharedCaching() -> (
        sensorData: RuuviTagDataService,
        alerts: RuuviTagAlertService,
        connections: RuuviTagConnectionService,
        settings: DashboardSettingsService,
        cloudSync: RuuviCloudService
    ) {

        let sensorDataService = createSensorDataService()
        let alertService = createAlertService()
        let connectionService = createConnectionService()
        let settingsService = createSettingsService()
        let cloudSyncService = createCloudSyncService()

        return (
            sensorData: sensorDataService,
            alerts: alertService,
            connections: connectionService,
            settings: settingsService,
            cloudSync: cloudSyncService
        )
    }
}
