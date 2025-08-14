// swiftlint:disable file_length
import BTKit
import Foundation
import RuuviAnalytics
import RuuviCloud
import RuuviContext
import RuuviCore
import RuuviDaemon
import RuuviDFU
import RuuviDiscover
import RuuviFirmware
import RuuviLocal
import RuuviLocalization
import RuuviMigration
import RuuviNotification
import RuuviNotifier
import RuuviPersistence
import RuuviPool
import RuuviPresenters
import RuuviReactor
import RuuviRepository
import RuuviService
import RuuviStorage
import RuuviUser
import Swinject

final class AppAssembly {
    static let shared = AppAssembly()
    var assembler: Assembler

    init() {
        assembler = Assembler(
            [
                BusinessAssembly(),
                CoreAssembly(),
                DaemonAssembly(),
                MigrationAssembly(),
                ModulesAssembly(),
                NetworkingAssembly(),
                PersistenceAssembly(),
                PresentationAssembly(),
                DfuAssembly(),
            ])
    }
}

private final class DfuAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviDFU.self) { _ in
            RuuviDFUImpl.shared
        }.inObjectScope(.container)
    }
}

private final class MigrationAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviMigrationFactory.self) { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let idPersistence = r.resolve(RuuviLocalIDs.self)!
            let ruuviPool = r.resolve(RuuviPool.self)!
            let sqliteContext = r.resolve(SQLiteContext.self)!
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let ruuviAlertService = r.resolve(RuuviServiceAlert.self)!
            let ruuviOffsetCalibrationService = r.resolve(RuuviServiceOffsetCalibration.self)!
            return RuuviMigrationFactoryImpl(
                settings: settings,
                idPersistence: idPersistence,
                ruuviPool: ruuviPool,
                sqliteContext: sqliteContext,
                ruuviStorage: ruuviStorage,
                ruuviAlertService: ruuviAlertService,
                ruuviOffsetCalibrationService: ruuviOffsetCalibrationService
            )
        }
    }
}

private final class PersistenceAssembly: Assembly {
    // swiftlint:disable:next function_body_length
    func assemble(container: Container) {
        container.register(RuuviLocalConnections.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalConnections()
        }

        container.register(RuuviLocalImages.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalImages()
        }

        container.register(RuuviLocalSyncState.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalSyncState()
        }.inObjectScope(.container)

        container.register(RuuviPoolFactory.self) { _ in
            RuuviPoolFactoryCoordinator()
        }

        container.register(RuuviPool.self) { r in
            let factory = r.resolve(RuuviPoolFactory.self)!
            let sqlite = r.resolve(RuuviPersistence.self, name: "sqlite")!
            let localIDs = r.resolve(RuuviLocalIDs.self)!
            let localSettings = r.resolve(RuuviLocalSettings.self)!
            let localConnections = r.resolve(RuuviLocalConnections.self)!
            return factory.create(
                sqlite: sqlite,
                idPersistence: localIDs,
                settings: localSettings,
                connectionPersistence: localConnections
            )
        }

        container.register(RuuviReactorFactory.self) { _ in
            RuuviReactorFactoryImpl()
        }

        container.register(RuuviErrorReporter.self) { _ in
            return RuuviErrorReporterImpl()
        }.inObjectScope(.container)

        container.register(RuuviReactor.self) { r in
            let factory = r.resolve(RuuviReactorFactory.self)!
            let sqliteContext = r.resolve(SQLiteContext.self)!
            let sqltePersistence = r.resolve(RuuviPersistence.self, name: "sqlite")!
            let errorReporter = r.resolve(RuuviErrorReporter.self)!
            return factory.create(
                sqliteContext: sqliteContext,
                sqlitePersistence: sqltePersistence,
                errorReporter: errorReporter
            )
        }.inObjectScope(.container)

        container.register(RuuviStorageFactory.self) { _ in
            let factory = RuuviStorageFactoryCoordinator()
            return factory
        }

        container.register(RuuviPersistence.self, name: "sqlite") { r in
            let context = r.resolve(SQLiteContext.self)!
            return RuuviPersistenceSQLite(context: context)
        }.inObjectScope(.container)

        container.register(RuuviStorage.self) { r in
            let factory = r.resolve(RuuviStorageFactory.self)!
            let sqlite = r.resolve(RuuviPersistence.self, name: "sqlite")!
            return factory.create(sqlite: sqlite)
        }.inObjectScope(.container)

        container.register(RuuviLocalFactory.self) { _ in
            let factory = RuuviLocalFactoryUserDefaults()
            return factory
        }

        container.register(RuuviLocalFlags.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalFlags()
        }

        container.register(RuuviLocalSettings.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalSettings()
        }

        container.register(RuuviLocalIDs.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalIDs()
        }

        container.register(SQLiteContextFactory.self) { _ in
            let factory = SQLiteContextFactoryGRDB()
            return factory
        }

        container.register(SQLiteContext.self) { r in
            let factory = r.resolve(SQLiteContextFactory.self)!
            return factory.create()
        }.inObjectScope(.container)
    }
}

private final class NetworkingAssembly: Assembly {
    func assemble(container: Container) {
        let appGroupDefaults = UserDefaults(
            suiteName: AppGroupConstants.appGroupSuiteIdentifier
        )
        let useDevServer = appGroupDefaults?.bool(
            forKey: AppGroupConstants.useDevServerKey
        ) ?? false

        container.register(RuuviCloud.self) { r in
            let user = r.resolve(RuuviUser.self)!
            let pool = r.resolve(RuuviPool.self)!
            let baseUrlString: String = useDevServer ?
                AppAssemblyConstants.ruuviCloudUrlDev : AppAssemblyConstants.ruuviCloudUrl
            let baseUrl = URL(string: baseUrlString)!
            let cloud = r.resolve(RuuviCloudFactory.self)!.create(
                baseUrl: baseUrl,
                user: user,
                pool: pool
            )
            return cloud
        }

        container.register(RuuviCloudFactory.self) { _ in
            RuuviCloudFactoryPure()
        }
    }
}

private final class DaemonAssembly: Assembly {
    // swiftlint:disable:next function_body_length
    func assemble(container: Container) {
        container.register(BackgroundProcessService.self) { r in
            let dataPruningOperationsManager = r.resolve(DataPruningOperationsManager.self)!
            let service = BackgroundProcessServiceiOS13(
                dataPruningOperationsManager: dataPruningOperationsManager
            )
            return service
        }.inObjectScope(.container)

        container.register(DataPruningOperationsManager.self) { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let ruuviPool = r.resolve(RuuviPool.self)!
            let manager = DataPruningOperationsManager(
                settings: settings,
                ruuviStorage: ruuviStorage,
                ruuviPool: ruuviPool
            )
            return manager
        }

        container.register(RuuviTagAdvertisementDaemon.self) { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let foreground = r.resolve(BTForeground.self)!
            let ruuviPool = r.resolve(RuuviPool.self)!
            let ruuviReactor = r.resolve(RuuviReactor.self)!
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let daemon = RuuviTagAdvertisementDaemonBTKit(
                ruuviPool: ruuviPool,
                ruuviStorage: ruuviStorage,
                ruuviReactor: ruuviReactor,
                foreground: foreground,
                settings: settings
            )
            return daemon
        }.inObjectScope(.container)

        container.register(RuuviTagHeartbeatDaemon.self) { r in
            let background = r.resolve(BTBackground.self)!
            let localNotificationsManager = r.resolve(RuuviNotificationLocal.self)!
            let connectionPersistence = r.resolve(RuuviLocalConnections.self)!
            let ruuviPool = r.resolve(RuuviPool.self)!
            let ruuviReactor = r.resolve(RuuviReactor.self)!
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let alertHandler = r.resolve(RuuviNotifier.self)!
            let alertService = r.resolve(RuuviServiceAlert.self)!
            let settings = r.resolve(RuuviLocalSettings.self)!
            let daemon = RuuviTagHeartbeatDaemonBTKit(
                background: background,
                localNotificationsManager: localNotificationsManager,
                connectionPersistence: connectionPersistence,
                ruuviPool: ruuviPool,
                ruuviStorage: ruuviStorage,
                ruuviReactor: ruuviReactor,
                alertService: alertService,
                alertHandler: alertHandler,
                settings: settings,
                titles: HeartbeatDaemonTitles()
            )
            return daemon
        }.inObjectScope(.container)

        container.register(RuuviTagPropertiesDaemon.self) { r in
            let ruuviReactor = r.resolve(RuuviReactor.self)!
            let ruuviPool = r.resolve(RuuviPool.self)!
            let foreground = r.resolve(BTForeground.self)!
            let idPersistence = r.resolve(RuuviLocalIDs.self)!
            let sqiltePersistence = r.resolve(RuuviPersistence.self, name: "sqlite")!
            let daemon = RuuviTagPropertiesDaemonBTKit(
                ruuviPool: ruuviPool,
                ruuviReactor: ruuviReactor,
                foreground: foreground,
                idPersistence: idPersistence,
                sqiltePersistence: sqiltePersistence
            )
            return daemon
        }.inObjectScope(.container)
    }
}

// swiftlint:disable:next type_body_length
private final class BusinessAssembly: Assembly {
    // swiftlint:disable:next function_body_length
    func assemble(container: Container) {
        container.register(RuuviNotifier.self) { r in
            let notificationLocal = r.resolve(RuuviNotificationLocal.self)!
            let ruuviAlertService = r.resolve(RuuviServiceAlert.self)!
            let localSyncState = r.resolve(RuuviLocalSyncState.self)!
            let measurementService = r.resolve(RuuviServiceMeasurement.self)!
            let titles = RuuviNotifierTitlesImpl()
            let service = RuuviNotifierImpl(
                ruuviAlertService: ruuviAlertService,
                ruuviNotificationLocal: notificationLocal,
                localSyncState: localSyncState,
                measurementService: measurementService,
                titles: titles
            )
            return service
        }.inObjectScope(.container)

        container.register(AppStateService.self) { r in
            let service = AppStateServiceImpl()
            service.settings = r.resolve(RuuviLocalSettings.self)
            service.advertisementDaemon = r.resolve(RuuviTagAdvertisementDaemon.self)
            service.propertiesDaemon = r.resolve(RuuviTagPropertiesDaemon.self)
            service.cloudSyncDaemon = r.resolve(RuuviDaemonCloudSync.self)
            service.heartbeatDaemon = r.resolve(RuuviTagHeartbeatDaemon.self)
            service.ruuviUser = r.resolve(RuuviUser.self)
            service.backgroundProcessService = r.resolve(BackgroundProcessService.self)
            service.userPropertiesService = r.resolve(RuuviAnalytics.self)
            service.universalLinkCoordinator = r.resolve(UniversalLinkCoordinator.self)
            return service
        }.inObjectScope(.container)

        container.register(RuuviServiceExport.self) { r in
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let measurementService = r.resolve(RuuviServiceMeasurement.self)!
            let localSettings = r.resolve(RuuviLocalSettings.self)!
            let service = RuuviServiceExportImpl(
                ruuviStorage: ruuviStorage,
                measurementService: measurementService,
                emptyValueString: "",
                ruuviLocalSettings: localSettings
            )
            return service
        }

        container.register(FallbackFeatureToggleProvider.self) { _ in
            let provider = FallbackFeatureToggleProvider()
            return provider
        }.inObjectScope(.container)

        container.register(FeatureToggleService.self) { r in
            let service = FeatureToggleService()
            service.firebaseProvider = r.resolve(FirebaseFeatureToggleProvider.self)
            service.fallbackProvider = r.resolve(FallbackFeatureToggleProvider.self)
            service.localProvider = r.resolve(LocalFeatureToggleProvider.self)
            return service
        }.inObjectScope(.container)

        container.register(FirebaseFeatureToggleProvider.self) { r in
            let provider = FirebaseFeatureToggleProvider()
            provider.remoteConfigService = r.resolve(RemoteConfigService.self)
            return provider
        }.inObjectScope(.container)

        container.register(GATTService.self) { r in
            let ruuviPool = r.resolve(RuuviPool.self)!
            let background = r.resolve(BTBackground.self)!
            let service = GATTServiceQueue(
                ruuviPool: ruuviPool,
                background: background
            )
            return service
        }.inObjectScope(.container)

        container.register(LocalFeatureToggleProvider.self) { _ in
            let provider = LocalFeatureToggleProvider()
            return provider
        }.inObjectScope(.container)

        container.register(RemoteConfigService.self) { _ in
            let service = FirebaseRemoteConfigService()
            return service
        }.inObjectScope(.container)

        container.register(RuuviDaemonFactory.self) { _ in
            RuuviDaemonFactoryImpl()
        }

        container.register(RuuviDaemonCloudSync.self) { r in
            let factory = r.resolve(RuuviDaemonFactory.self)!
            let localSettings = r.resolve(RuuviLocalSettings.self)!
            let localSyncState = r.resolve(RuuviLocalSyncState.self)!
            let cloudSyncService = r.resolve(RuuviServiceCloudSync.self)!
            return factory.createCloudSync(
                localSettings: localSettings,
                localSyncState: localSyncState,
                cloudSyncService: cloudSyncService
            )
        }.inObjectScope(.container)

        container.register(RuuviRepositoryFactory.self) { _ in
            RuuviRepositoryFactoryCoordinator()
        }

        container.register(RuuviRepository.self) { r in
            let factory = r.resolve(RuuviRepositoryFactory.self)!
            let pool = r.resolve(RuuviPool.self)!
            let storage = r.resolve(RuuviStorage.self)!
            return factory.create(
                pool: pool,
                storage: storage
            )
        }

        container.register(RuuviServiceFactory.self) { _ in
            RuuviServiceFactoryImpl()
        }

        container.register(RuuviServiceAlert.self) { r in
            let factory = r.resolve(RuuviServiceFactory.self)!
            let cloud = r.resolve(RuuviCloud.self)!
            let localIDs = r.resolve(RuuviLocalIDs.self)!
            let ruuviLocalSettings = r.resolve(RuuviLocalSettings.self)!
            return factory.createAlert(
                ruuviCloud: cloud,
                ruuviLocalIDs: localIDs,
                ruuviLocalSettings: ruuviLocalSettings
            )
        }

        container.register(RuuviServiceOffsetCalibration.self) { r in
            let factory = r.resolve(RuuviServiceFactory.self)!
            let cloud = r.resolve(RuuviCloud.self)!
            let pool = r.resolve(RuuviPool.self)!
            return factory.createOffsetCalibration(
                ruuviCloud: cloud,
                ruuviPool: pool
            )
        }

        container.register(RuuviServiceAppSettings.self) { r in
            let factory = r.resolve(RuuviServiceFactory.self)!
            let cloud = r.resolve(RuuviCloud.self)!
            let localSettings = r.resolve(RuuviLocalSettings.self)!
            return factory.createAppSettings(
                ruuviCloud: cloud,
                ruuviLocalSettings: localSettings
            )
        }

        container.register(RuuviServiceAuth.self) { r in
            let factory = r.resolve(RuuviServiceFactory.self)!
            let user = r.resolve(RuuviUser.self)!
            let pool = r.resolve(RuuviPool.self)!
            let storage = r.resolve(RuuviStorage.self)!
            let propertiesService = r.resolve(RuuviServiceSensorProperties.self)!
            let localIDs = r.resolve(RuuviLocalIDs.self)!
            let localSyncState = r.resolve(RuuviLocalSyncState.self)!
            let alertService = r.resolve(RuuviServiceAlert.self)!
            let settings = r.resolve(RuuviLocalSettings.self)!
            return factory.createAuth(
                ruuviUser: user,
                pool: pool,
                storage: storage,
                propertiesService: propertiesService,
                localIDs: localIDs,
                localSyncState: localSyncState,
                alertService: alertService,
                settings: settings
            )
        }

        container.register(RuuviServiceCloudSync.self) { r in
            let factory = r.resolve(RuuviServiceFactory.self)!
            let storage = r.resolve(RuuviStorage.self)!
            let cloud = r.resolve(RuuviCloud.self)!
            let pool = r.resolve(RuuviPool.self)!
            let localSettings = r.resolve(RuuviLocalSettings.self)!
            let localSyncState = r.resolve(RuuviLocalSyncState.self)!
            let localImages = r.resolve(RuuviLocalImages.self)!
            let repository = r.resolve(RuuviRepository.self)!
            let localIDs = r.resolve(RuuviLocalIDs.self)!
            let alertService = r.resolve(RuuviServiceAlert.self)!
            let ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)!
            return factory.createCloudSync(
                ruuviStorage: storage,
                ruuviCloud: cloud,
                ruuviPool: pool,
                ruuviLocalSettings: localSettings,
                ruuviLocalSyncState: localSyncState,
                ruuviLocalImages: localImages,
                ruuviRepository: repository,
                ruuviLocalIDs: localIDs,
                ruuviAlertService: alertService,
                ruuviAppSettingsService: ruuviAppSettingsService
            )
        }

        container.register(RuuviServiceOwnership.self) { r in
            let factory = r.resolve(RuuviServiceFactory.self)!
            let pool = r.resolve(RuuviPool.self)!
            let cloud = r.resolve(RuuviCloud.self)!
            let propertiesService = r.resolve(RuuviServiceSensorProperties.self)!
            let localIDs = r.resolve(RuuviLocalIDs.self)!
            let localImages = r.resolve(RuuviLocalImages.self)!
            let storage = r.resolve(RuuviStorage.self)!
            let alertService = r.resolve(RuuviServiceAlert.self)!
            let user = r.resolve(RuuviUser.self)!
            let localSyncState = r.resolve(RuuviLocalSyncState.self)!
            let settings = r.resolve(RuuviLocalSettings.self)!
            return factory.createOwnership(
                ruuviCloud: cloud,
                ruuviPool: pool,
                propertiesService: propertiesService,
                localIDs: localIDs,
                localImages: localImages,
                storage: storage,
                alertService: alertService,
                ruuviUser: user,
                localSyncState: localSyncState,
                settings: settings
            )
        }

        container.register(RuuviServiceSensorProperties.self) { r in
            let factory = r.resolve(RuuviServiceFactory.self)!
            let pool = r.resolve(RuuviPool.self)!
            let cloud = r.resolve(RuuviCloud.self)!
            let coreImage = r.resolve(RuuviCoreImage.self)!
            let localImages = r.resolve(RuuviLocalImages.self)!
            return factory.createSensorProperties(
                ruuviPool: pool,
                ruuviCloud: cloud,
                ruuviCoreImage: coreImage,
                ruuviLocalImages: localImages
            )
        }

        container.register(RuuviServiceSensorRecords.self) { r in
            let factory = r.resolve(RuuviServiceFactory.self)!
            let pool = r.resolve(RuuviPool.self)!
            let syncState = r.resolve(RuuviLocalSyncState.self)!
            return factory.createSensorRecords(
                ruuviPool: pool,
                ruuviLocalSyncState: syncState
            )
        }

        container.register(RuuviUserFactory.self) { _ in
            RuuviUserFactoryCoordinator()
        }

        container.register(RuuviUser.self) { r in
            let factory = r.resolve(RuuviUserFactory.self)!
            return factory.createUser()
        }.inObjectScope(.container)

        container.register(RuuviAnalytics.self) { r in
            let ruuviUser = r.resolve(RuuviUser.self)!
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let settings = r.resolve(RuuviLocalSettings.self)!
            let alertService = r.resolve(RuuviServiceAlert.self)!
            let service = RuuviAnalyticsImpl(
                ruuviUser: ruuviUser,
                ruuviStorage: ruuviStorage,
                settings: settings,
                alertService: alertService
            )
            return service
        }

        container.register(UniversalLinkCoordinator.self, factory: { r in
            let coordinator = UniversalLinkCoordinatorImpl()
            let router = UniversalLinkRouterImpl()
            coordinator.ruuviUser = r.resolve(RuuviUser.self)
            coordinator.settings = r.resolve(RuuviLocalSettings.self)
            coordinator.router = router
            return coordinator
        })

        container.register(RuuviServiceCloudNotification.self) { r in
            let factory = r.resolve(RuuviServiceFactory.self)!
            let pool = r.resolve(RuuviPool.self)!
            let cloud = r.resolve(RuuviCloud.self)!
            let storage = r.resolve(RuuviStorage.self)!
            let user = r.resolve(RuuviUser.self)!
            let pnManager = r.resolve(RuuviCorePN.self)!
            return factory.createCloudNotification(
                ruuviCloud: cloud,
                ruuviPool: pool,
                storage: storage,
                ruuviUser: user,
                pnManager: pnManager
            )
        }
    }
}

private final class CoreAssembly: Assembly {
    func assemble(container: Container) {
        container.register(BTForeground.self) { _ in
            BTKit.foreground
        }.inObjectScope(.container)

        container.register(BTBackground.self) { _ in
            BTKit.background
        }.inObjectScope(.container)

        container.register(InfoProvider.self) { _ in
            let provider = InfoProviderImpl()
            return provider
        }

        container.register(RuuviNotificationLocal.self) { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let idPersistence = r.resolve(RuuviLocalIDs.self)!
            let ruuviAlertService = r.resolve(RuuviServiceAlert.self)!
            let manager = RuuviNotificationLocalImpl(
                ruuviStorage: ruuviStorage,
                idPersistence: idPersistence,
                settings: settings,
                ruuviAlertService: ruuviAlertService
            )
            return manager
        }.inObjectScope(.container)

        container.register(RuuviCoreLocation.self) { _ in
            let manager = RuuviCoreLocationImpl()
            return manager
        }

        container.register(RuuviCorePermission.self) { r in
            let locationManager = r.resolve(RuuviCoreLocation.self)!
            let manager = RuuviCorePermissionImpl(locationManager: locationManager)
            return manager
        }.inObjectScope(.container)

        container.register(RuuviCorePN.self) { _ in
            let manager = RuuviCorePNImpl()
            return manager
        }

        container.register(RuuviCoreImage.self) { _ in
            RuuviCoreImageImpl()
        }

        container.register(RuuviServiceMeasurement.self, factory: { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let service = RuuviServiceMeasurementImpl(
                settings: settings,
                emptyValueString: RuuviLocalization.na,
                percentString: "%"
            )
            return service
        })
    }
}

private final class ModulesAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviDiscover.self) { r in
            let errorPresenter = r.resolve(ErrorPresenter.self)!
            let activityPresenter = r.resolve(ActivityPresenter.self)!
            let permissionsManager = r.resolve(RuuviCorePermission.self)!
            let permissionPresenter = r.resolve(PermissionPresenter.self)!
            let foreground = r.resolve(BTForeground.self)!
            let background = r.resolve(BTBackground.self)!
            let ruuviReactor = r.resolve(RuuviReactor.self)!
            let ruuviOwnershipService = r.resolve(RuuviServiceOwnership.self)!
            let propertiesDaemon = r.resolve(RuuviTagPropertiesDaemon.self)!
            let ruuviDFU = r.resolve(RuuviDFU.self)!

            let factory = RuuviDiscoverFactory()
            let dependencies = RuuviDiscoverDependencies(
                errorPresenter: errorPresenter,
                activityPresenter: activityPresenter,
                permissionsManager: permissionsManager,
                permissionPresenter: permissionPresenter,
                foreground: foreground,
                background: background,
                propertiesDaemon: propertiesDaemon,
                ruuviDFU: ruuviDFU,
                ruuviReactor: ruuviReactor,
                ruuviOwnershipService: ruuviOwnershipService,
                firmwareBuilder: RuuviFirmwareBuilder()
            )
            return factory.create(dependencies: dependencies)
        }
    }
}

// swiftlint:enable file_length
