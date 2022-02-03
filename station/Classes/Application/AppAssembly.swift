// swiftlint:disable file_length
import Swinject
import Foundation
import BTKit
import RuuviLocal
import RuuviPool
import RuuviContext
import RuuviVirtual
import RuuviStorage
import RuuviService
import RuuviDFU
import RuuviMigration
import RuuviPersistence
import RuuviReactor
import RuuviCloud
import RuuviUser
import RuuviDaemon
import RuuviNotifier
import RuuviNotification
import RuuviRepository
import RuuviLocation
import RuuviCore
#if canImport(RuuviCloudPure)
import RuuviCloudPure
#endif
#if canImport(RuuviVirtualOWM)
import RuuviVirtualOWM
#endif
#if canImport(RuuviContextRealm)
import RuuviContextRealm
#endif
#if canImport(RuuviContextSQLite)
import RuuviContextSQLite
#endif
#if canImport(RuuviPersistenceRealm)
import RuuviPersistenceRealm
#endif
#if canImport(RuuviPersistenceSQLite)
import RuuviPersistenceSQLite
#endif
#if canImport(RuuviStorageCoordinator)
import RuuviStorageCoordinator
#endif
#if canImport(RuuviPoolCoordinator)
import RuuviPoolCoordinator
#endif
#if canImport(RuuviLocalUserDefaults)
import RuuviLocalUserDefaults
#endif
#if canImport(RuuviPoolCoordinator)
import RuuviPoolCoordinator
#endif
#if canImport(RuuviReactorImpl)
import RuuviReactorImpl
#endif
#if canImport(RuuviDFUImpl)
import RuuviDFUImpl
#endif
#if canImport(RuuviMigrationImpl)
import RuuviMigrationImpl
#endif
#if canImport(RuuviVirtualPersistence)
import RuuviVirtualPersistence
#endif
#if canImport(RuuviVirtualReactor)
import RuuviVirtualReactor
#endif
#if canImport(RuuviVirtualRepository)
import RuuviVirtualRepository
#endif
#if canImport(RuuviVirtualStorage)
import RuuviVirtualStorage
#endif
#if canImport(RuuviDaemonOperation)
import RuuviDaemonOperation
#endif
#if canImport(RuuviDaemonBackground)
import RuuviDaemonBackground
#endif
#if canImport(RuuviDaemonRuuviTag)
import RuuviDaemonRuuviTag
#endif
#if canImport(RuuviDaemonVirtualTag)
import RuuviDaemonVirtualTag
#endif
#if canImport(RuuviServiceGATT)
import RuuviServiceGATT
#endif
#if canImport(RuuviAnalytics)
import RuuviAnalytics
#endif
#if canImport(RuuviAnalyticsImpl)
import RuuviAnalyticsImpl
#endif
#if canImport(RuuviServiceExport)
import RuuviServiceExport
#endif
#if canImport(RuuviNotifierImpl)
import RuuviNotifierImpl
#endif
#if canImport(RuuviServiceFactory)
import RuuviServiceFactory
#endif
#if canImport(RuuviDaemonCloudSync)
import RuuviDaemonCloudSync
#endif
#if canImport(RuuviRepositoryCoordinator)
import RuuviRepositoryCoordinator
#endif
#if canImport(RuuviUserCoordinator)
import RuuviUserCoordinator
#endif
#if canImport(RuuviCoreLocation)
import RuuviCoreLocation
#endif
#if canImport(RuuviLocationService)
import RuuviLocationService
#endif
#if canImport(RuuviVirtualOWM)
import RuuviVirtualOWM
#endif
#if canImport(RuuviVirtualService)
import RuuviVirtualService
#endif
#if canImport(RuuviNotificationLocal)
import RuuviNotificationLocal
#endif
#if canImport(RuuviCoreImage)
import RuuviCoreImage
#endif
#if canImport(RuuviCoreLocation)
import RuuviCoreLocation
#endif
#if canImport(RuuviLocationService)
import RuuviLocationService
#endif
#if canImport(RuuviCorePN)
import RuuviCorePN
#endif
#if canImport(RuuviCorePermission)
import RuuviCorePermission
#endif
#if canImport(RuuviServiceMeasurement)
import RuuviServiceMeasurement
#endif

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
                NetworkingAssembly(),
                PersistenceAssembly(),
                PresentationAssembly(),
                DfuAssembly(),
                VirtualAssembly()
            ])
    }
}

private final class DfuAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviDFU.self) { _ in
            return RuuviDFUImpl.shared
        }.inObjectScope(.container)
    }
}

private final class MigrationAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviMigration.self, name: "realm") { r in
            let localImages = r.resolve(RuuviLocalImages.self)!
            let settings = r.resolve(RuuviLocalSettings.self)!
            return MigrationManagerToVIPER(localImages: localImages, settings: settings)
        }

        container.register(RuuviMigrationFactory.self) { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let idPersistence = r.resolve(RuuviLocalIDs.self)!
            let realmContext = r.resolve(RealmContext.self)!
            let ruuviPool = r.resolve(RuuviPool.self)!
            let virtualStorage = r.resolve(VirtualStorage.self)!
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let ruuviAlertService = r.resolve(RuuviServiceAlert.self)!
            let ruuviOffsetCalibrationService = r.resolve(RuuviServiceOffsetCalibration.self)!
            return RuuviMigrationFactoryImpl(
                settings: settings,
                idPersistence: idPersistence,
                realmContext: realmContext,
                ruuviPool: ruuviPool,
                virtualStorage: virtualStorage,
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
        container.register(RealmContextFactory.self) { _ in
            let factory = RealmContextFactoryImpl()
            return factory
        }.inObjectScope(.container)

        container.register(RealmContext.self) { r in
            let factory = r.resolve(RealmContextFactory.self)!
            return factory.create()
        }.inObjectScope(.container)

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
            return RuuviPoolFactoryCoordinator()
        }

        container.register(RuuviPool.self) { r in
            let factory = r.resolve(RuuviPoolFactory.self)!
            let realm = r.resolve(RuuviPersistence.self, name: "realm")!
            let sqlite = r.resolve(RuuviPersistence.self, name: "sqlite")!
            let localIDs = r.resolve(RuuviLocalIDs.self)!
            let localSettings = r.resolve(RuuviLocalSettings.self)!
            let localConnections = r.resolve(RuuviLocalConnections.self)!
            return factory.create(
                sqlite: sqlite,
                realm: realm,
                idPersistence: localIDs,
                settings: localSettings,
                connectionPersistence: localConnections
            )
        }

        container.register(RuuviReactorFactory.self) { _ in
            return RuuviReactorFactoryImpl()
        }

        container.register(RuuviReactor.self) { r in
            let factory = r.resolve(RuuviReactorFactory.self)!
            let sqliteContext = r.resolve(SQLiteContext.self)!
            let realmContext = r.resolve(RealmContext.self)!
            let sqltePersistence = r.resolve(RuuviPersistence.self, name: "sqlite")!
            let realmPersistence = r.resolve(RuuviPersistence.self, name: "realm")!
            return factory.create(
                sqliteContext: sqliteContext,
                realmContext: realmContext,
                sqlitePersistence: sqltePersistence,
                realmPersistence: realmPersistence
            )
        }.inObjectScope(.container)

        container.register(RuuviStorageFactory.self) { _ in
            let factory = RuuviStorageFactoryCoordinator()
            return factory
        }

        container.register(RuuviPersistence.self, name: "realm") { r in
            let context = r.resolve(RealmContext.self)!
            return RuuviPersistenceRealm(context: context)
        }.inObjectScope(.container)

        container.register(RuuviPersistence.self, name: "sqlite") { r in
            let context = r.resolve(SQLiteContext.self)!
            return RuuviPersistenceSQLite(context: context)
        }.inObjectScope(.container)

        container.register(RuuviStorage.self) { r in
            let factory = r.resolve(RuuviStorageFactory.self)!
            let sqlite = r.resolve(RuuviPersistence.self, name: "sqlite")!
            let realm = r.resolve(RuuviPersistence.self, name: "realm")!
            return factory.create(realm: realm, sqlite: sqlite)
        }.inObjectScope(.container)

        container.register(RuuviLocalFactory.self) { _ in
            let factory = RuuviLocalFactoryUserDefaults()
            return factory
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

        container.register(OpenWeatherMapAPI.self) { _ in
            let apiKey: String = AppAssemblyConstants.openWeatherMapApiKey
            let api = OpenWeatherMapAPIURLSession(apiKey: apiKey)
            return api
        }

        container.register(RuuviCloud.self) { r in
            let user = r.resolve(RuuviUser.self)!
            let baseUrlString: String = AppAssemblyConstants.ruuviCloudUrl
            let baseUrl = URL(string: baseUrlString)!
            let cloud = r.resolve(RuuviCloudFactory.self)!.create(
                baseUrl: baseUrl,
                user: user
            )
            return cloud
        }

        container.register(RuuviCloudFactory.self) { _ in
            return RuuviCloudFactoryPure()
        }
    }
}

private final class VirtualAssembly: Assembly {
    func assemble(container: Container) {
        container.register(VirtualPersistence.self) { r in
            let context = r.resolve(RealmContext.self)!
            let settings = r.resolve(RuuviLocalSettings.self)!
            return VirtualPersistenceRealm(context: context, settings: settings)
        }

        container.register(VirtualReactor.self) { r in
            let context = r.resolve(RealmContext.self)!
            let persistence = r.resolve(VirtualPersistence.self)!
            return VirtualReactorImpl(context: context, persistence: persistence)
        }.inObjectScope(.container)

        container.register(VirtualRepository.self) { r in
            let persistence = r.resolve(VirtualPersistence.self)!
            return VirtualRepositoryCoordinator(persistence: persistence)
        }

        container.register(VirtualStorage.self) { r in
            let persistence = r.resolve(VirtualPersistence.self)!
            return VirtualStorageCoordinator(persistence: persistence)
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

        container.register(BackgroundTaskService.self) { r in
            let webTagOperationsManager = r.resolve(WebTagOperationsManager.self)!
            let service = BackgroundTaskServiceiOS13(
                webTagOperationsManager: webTagOperationsManager
            )
            return service
        }.inObjectScope(.container)

        container.register(DataPruningOperationsManager.self) { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let virtualStorage = r.resolve(VirtualStorage.self)!
            let virtualRepository = r.resolve(VirtualRepository.self)!
            let ruuviPool = r.resolve(RuuviPool.self)!
            let manager = DataPruningOperationsManager(
                settings: settings,
                virtualStorage: virtualStorage,
                virtualRepository: virtualRepository,
                ruuviStorage: ruuviStorage,
                ruuviPool: ruuviPool
            )
            return manager
        }

        container.register(PullWebDaemon.self) { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let webTagOperationsManager = r.resolve(WebTagOperationsManager.self)!
            let daemon = PullWebDaemonOperations(
                settings: settings,
                webTagOperationsManager: webTagOperationsManager
            )
            return daemon
        }.inObjectScope(.container)

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
            let pullWebDaemon = r.resolve(PullWebDaemon.self)!
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
                pullWebDaemon: pullWebDaemon,
                titles: HeartbeatDaemonTitles()
            )
            return daemon
        }.inObjectScope(.container)

        container.register(RuuviTagPropertiesDaemon.self) { r in
            let ruuviReactor = r.resolve(RuuviReactor.self)!
            let ruuviPool = r.resolve(RuuviPool.self)!
            let foreground = r.resolve(BTForeground.self)!
            let idPersistence = r.resolve(RuuviLocalIDs.self)!
            let realmPersistence = r.resolve(RuuviPersistence.self, name: "realm")!
            let sqiltePersistence = r.resolve(RuuviPersistence.self, name: "sqlite")!
            let daemon = RuuviTagPropertiesDaemonBTKit(
                ruuviPool: ruuviPool,
                ruuviReactor: ruuviReactor,
                foreground: foreground,
                idPersistence: idPersistence,
                realmPersistence: realmPersistence,
                sqiltePersistence: sqiltePersistence
            )
            return daemon
        }.inObjectScope(.container)

        container.register(VirtualTagDaemon.self) { r in
            let virtualService = r.resolve(VirtualService.self)!
            let settings = r.resolve(RuuviLocalSettings.self)!
            let virtualPersistence = r.resolve(VirtualPersistence.self)!
            let alertService = r.resolve(RuuviNotifier.self)!
            let virtualReactor = r.resolve(VirtualReactor.self)!
            let daemon = VirtualTagDaemonImpl(
                virtualService: virtualService,
                settings: settings,
                virtualPersistence: virtualPersistence,
                alertService: alertService,
                virtualReactor: virtualReactor
            )
            return daemon
        }.inObjectScope(.container)

        container.register(WebTagOperationsManager.self) { r in
            let alertService = r.resolve(RuuviServiceAlert.self)!
            let ruuviNotifier = r.resolve(RuuviNotifier.self)!
            let virtualProviderService = r.resolve(VirtualProviderService.self)!
            let virtualStorage = r.resolve(VirtualStorage.self)!
            let virtualPersistence = r.resolve(VirtualPersistence.self)!
            let manager = WebTagOperationsManager(
                virtualProviderService: virtualProviderService,
                alertService: alertService,
                alertHandler: ruuviNotifier,
                virtualStorage: virtualStorage,
                virtualPersistence: virtualPersistence
            )
            return manager
        }
    }
}

// swiftlint:disable:next type_body_length
private final class BusinessAssembly: Assembly {
    // swiftlint:disable:next function_body_length
    func assemble(container: Container) {
        container.register(RuuviNotifier.self) { r in
            let notificationLocal = r.resolve(RuuviNotificationLocal.self)!
            let ruuviAlertService = r.resolve(RuuviServiceAlert.self)!
            let titles = RuuviNotifierTitlesImpl()
            let service = RuuviNotifierImpl(
                ruuviAlertService: ruuviAlertService,
                ruuviNotificationLocal: notificationLocal,
                titles: titles
            )
            return service
        }.inObjectScope(.container)

        container.register(AppStateService.self) { r in
            let service = AppStateServiceImpl()
            service.settings = r.resolve(RuuviLocalSettings.self)
            service.advertisementDaemon = r.resolve(RuuviTagAdvertisementDaemon.self)
            service.propertiesDaemon = r.resolve(RuuviTagPropertiesDaemon.self)
            service.webTagDaemon = r.resolve(VirtualTagDaemon.self)
            service.cloudSyncDaemon = r.resolve(RuuviDaemonCloudSync.self)
            service.heartbeatDaemon = r.resolve(RuuviTagHeartbeatDaemon.self)
            service.ruuviUser = r.resolve(RuuviUser.self)
            service.pullWebDaemon = r.resolve(PullWebDaemon.self)
            service.backgroundTaskService = r.resolve(BackgroundTaskService.self)
            service.backgroundProcessService = r.resolve(BackgroundProcessService.self)
            #if canImport(RuuviAnalytics)
            service.userPropertiesService = r.resolve(RuuviAnalytics.self)
            #endif
            service.universalLinkCoordinator = r.resolve(UniversalLinkCoordinator.self)
            return service
        }.inObjectScope(.container)

        container.register(RuuviServiceExport.self) { r in
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let measurementService = r.resolve(RuuviServiceMeasurement.self)!
            let service = RuuviServiceExportImpl(
                ruuviStorage: ruuviStorage,
                measurementService: measurementService,
                headersProvider: ExportHeadersProvider(),
                emptyValueString: "N/A".localized()
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

        container.register(RuuviLocationService.self) { _ in
            let service = RuuviLocationServiceApple()
            return service
        }

        container.register(RemoteConfigService.self) { _ in
            let service = FirebaseRemoteConfigService()
            return service
        }.inObjectScope(.container)

        container.register(RuuviDaemonFactory.self) { _ in
            return RuuviDaemonFactoryImpl()
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
            return RuuviRepositoryFactoryCoordinator()
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
            return RuuviServiceFactoryImpl()
        }

        container.register(RuuviServiceAlert.self) { r in
            let factory = r.resolve(RuuviServiceFactory.self)!
            let cloud = r.resolve(RuuviCloud.self)!
            let localIDs = r.resolve(RuuviLocalIDs.self)!
            return factory.createAlert(
                ruuviCloud: cloud,
                ruuviLocalIDs: localIDs
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
            return factory.createAuth(
                ruuviUser: user,
                pool: pool,
                storage: storage,
                propertiesService: propertiesService,
                localIDs: localIDs,
                localSyncState: localSyncState
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
            return factory.createCloudSync(
                ruuviStorage: storage,
                ruuviCloud: cloud,
                ruuviPool: pool,
                ruuviLocalSettings: localSettings,
                ruuviLocalSyncState: localSyncState,
                ruuviLocalImages: localImages,
                ruuviRepository: repository,
                ruuviLocalIDs: localIDs,
                ruuviAlertService: alertService
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
            return factory.createOwnership(
                ruuviCloud: cloud,
                ruuviPool: pool,
                propertiesService: propertiesService,
                localIDs: localIDs,
                localImages: localImages,
                storage: storage,
                alertService: alertService,
                ruuviUser: user
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
            return RuuviUserFactoryCoordinator()
        }

        container.register(RuuviUser.self) { r in
            let factory = r.resolve(RuuviUserFactory.self)!
            return factory.createUser()
        }.inObjectScope(.container)

        container.register(VirtualProviderService.self) { r in
            let owmApi = r.resolve(OpenWeatherMapAPI.self)!
            let locationManager = r.resolve(RuuviCoreLocation.self)!
            let locationService = r.resolve(RuuviLocationService.self)!
            let service = VirtualProviderServiceImpl(
                owmApi: owmApi,
                ruuviCoreLocation: locationManager,
                ruuviLocationService: locationService
            )
            return service
        }

        container.register(VirtualService.self) { r in
            let virtualPersistence = r.resolve(VirtualPersistence.self)!
            let weatherProviderService = r.resolve(VirtualProviderService.self)!
            let ruuviLocalImages = r.resolve(RuuviLocalImages.self)!
            let service = VirtualServiceImpl(
                ruuviLocalImages: ruuviLocalImages,
                virtualPersistence: virtualPersistence,
                virtualProviderService: weatherProviderService
            )
            return service
        }
        #if canImport(RuuviAnalytics)
        container.register(RuuviAnalytics.self) { r in
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let settings = r.resolve(RuuviLocalSettings.self)!
            let service = RuuviAnalyticsImpl(
                ruuviStorage: ruuviStorage,
                settings: settings
            )
            return service
        }
        #endif
        container.register(UniversalLinkCoordinator.self, factory: { r in
            let coordinator = UniversalLinkCoordinatorImpl()
            let router = UniversalLinkRouterImpl()
            coordinator.ruuviUser = r.resolve(RuuviUser.self)
            coordinator.router = router
            return coordinator
        })
    }
}

private final class CoreAssembly: Assembly {
    // swiftlint:disable:next function_body_length
    func assemble(container: Container) {
        container.register(BTForeground.self) { _ in
            return BTKit.foreground
        }.inObjectScope(.container)

        container.register(BTBackground.self) { _ in
            return BTKit.background
        }.inObjectScope(.container)

        container.register(InfoProvider.self) { _ in
            let provider = InfoProviderImpl()
            return provider
        }

        container.register(RuuviNotificationLocal.self) { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let virtualTagTrunk = r.resolve(VirtualStorage.self)!
            let idPersistence = r.resolve(RuuviLocalIDs.self)!
            let ruuviAlertService = r.resolve(RuuviServiceAlert.self)!
            let manager = RuuviNotificationLocalImpl(
                ruuviStorage: ruuviStorage,
                virtualTagTrunk: virtualTagTrunk,
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
            return RuuviCoreImageImpl()
        }

        container.register(RuuviServiceMeasurement.self, factory: { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let service = RuuviServiceMeasurementImpl(
                settings: settings,
                emptyValueString: "N/A".localized(),
                percentString: "%".localized()
            )
            return service
        })
    }
}

// swiftlint:enable file_length
