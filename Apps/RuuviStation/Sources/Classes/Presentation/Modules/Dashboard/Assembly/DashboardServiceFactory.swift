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

    func createSettingsService() -> DashboardSettingsService {
        return DashboardSettingsService(
            settings: settings,
            ruuviAppSettingsService: ruuviAppSettingsService
        )
    }

    // MARK: - Complete Presenter Creation
    func createDashboardPresenter() -> DashboardPresenter {
        let settingsService = createSettingsService()

        return DashboardPresenter(
            settingsService: settingsService,
            serviceCoordinatorManager: RuuviTagServiceCoordinatorManager.shared
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
