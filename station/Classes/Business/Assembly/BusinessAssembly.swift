import Swinject
import BTKit
import RuuviContext
import RuuviStorage
import RuuviReactor
import RuuviPersistence
import RuuviLocal
import RuuviPool
import RuuviService
import RuuviCloud
import RuuviCore
import RuuviDaemon
import RuuviRepository
import RuuviUser
import RuuviVirtual
import RuuviLocation
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

// swiftlint:disable:next type_body_length
class BusinessAssembly: Assembly {
    // swiftlint:disable:next function_body_length
    func assemble(container: Container) {
        container.register(AlertService.self) { r in
            let service = AlertServiceImpl()
            service.ruuviAlertService = r.resolve(RuuviServiceAlert.self)
            return service
        }.inObjectScope(.container).initCompleted { (r, service) in
            // swiftlint:disable force_cast
            let s = service as! AlertServiceImpl
            // swiftlint:enable force_cast
            s.localNotificationsManager = r.resolve(LocalNotificationsManager.self)
        }

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
            service.userPropertiesService = r.resolve(UserPropertiesService.self)
            service.universalLinkCoordinator = r.resolve(UniversalLinkCoordinator.self)
            return service
        }.inObjectScope(.container)

        container.register(BackgroundProcessService.self) { r in
            if #available(iOS 13, *) {
                let service = BackgroundProcessServiceiOS13()
                service.dataPruningOperationsManager = r.resolve(DataPruningOperationsManager.self)
                return service
            } else {
                let service = BackgroundProcessServiceiOS12()
                service.dataPruningOperationsManager = r.resolve(DataPruningOperationsManager.self)
                return service
            }
        }.inObjectScope(.container)

        container.register(BackgroundTaskService.self) { r in
            if #available(iOS 13, *) {
                let service = BackgroundTaskServiceiOS13()
                service.webTagOperationsManager = r.resolve(WebTagOperationsManager.self)
                return service
            } else {
                let service = BackgroundTaskServiceiOS12()
                return service
            }
        }.inObjectScope(.container)

        container.register(DataPruningOperationsManager.self) { r in
            let manager = DataPruningOperationsManager()
            manager.settings = r.resolve(RuuviLocalSettings.self)
            manager.ruuviStorage = r.resolve(RuuviStorage.self)
            manager.virtualStorage = r.resolve(VirtualStorage.self)
            manager.virtualRepository = r.resolve(VirtualRepository.self)
            manager.ruuviPool = r.resolve(RuuviPool.self)
            return manager
        }

        container.register(ExportService.self) { r in
            let service = ExportServiceTrunk()
            service.ruuviStorage = r.resolve(RuuviStorage.self)
            service.measurementService = r.resolve(MeasurementsService.self)
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
            let service = GATTServiceQueue()
            service.ruuviPool = r.resolve(RuuviPool.self)
            service.background = r.resolve(BTBackground.self)
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

        container.register(PullWebDaemon.self) { r in
            let daemon = PullWebDaemonOperations()
            daemon.settings = r.resolve(RuuviLocalSettings.self)
            daemon.webTagOperationsManager = r.resolve(WebTagOperationsManager.self)
            return daemon
        }.inObjectScope(.container)

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
            return factory.createOwnership(
                ruuviCloud: cloud,
                ruuviPool: pool,
                propertiesService: propertiesService,
                localIDs: localIDs
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

        container.register(RuuviTagAdvertisementDaemon.self) { r in
            let daemon = RuuviTagAdvertisementDaemonBTKit()
            daemon.settings = r.resolve(RuuviLocalSettings.self)
            daemon.foreground = r.resolve(BTForeground.self)
            daemon.ruuviPool = r.resolve(RuuviPool.self)
            daemon.ruuviReactor = r.resolve(RuuviReactor.self)
            daemon.ruuviStorage = r.resolve(RuuviStorage.self)
            return daemon
        }.inObjectScope(.container)

        container.register(RuuviTagHeartbeatDaemon.self) { r in
            let daemon = RuuviTagHeartbeatDaemonBTKit()
            daemon.background = r.resolve(BTBackground.self)
            daemon.localNotificationsManager = r.resolve(LocalNotificationsManager.self)
            daemon.connectionPersistence = r.resolve(RuuviLocalConnections.self)
            daemon.ruuviPool = r.resolve(RuuviPool.self)
            daemon.ruuviReactor = r.resolve(RuuviReactor.self)
            daemon.ruuviStorage = r.resolve(RuuviStorage.self)
            daemon.alertHandler = r.resolve(AlertService.self)
            daemon.alertService = r.resolve(RuuviServiceAlert.self)
            daemon.settings = r.resolve(RuuviLocalSettings.self)
            daemon.pullWebDaemon = r.resolve(PullWebDaemon.self)
            return daemon
        }.inObjectScope(.container)

        container.register(RuuviTagPropertiesDaemon.self) { r in
            let daemon = RuuviTagPropertiesDaemonBTKit()
            daemon.ruuviReactor = r.resolve(RuuviReactor.self)
            daemon.ruuviPool = r.resolve(RuuviPool.self)
            daemon.foreground = r.resolve(BTForeground.self)
            daemon.idPersistence = r.resolve(RuuviLocalIDs.self)
            daemon.realmPersistence = r.resolve(RuuviPersistence.self, name: "realm")
            daemon.sqiltePersistence = r.resolve(RuuviPersistence.self, name: "sqlite")
            return daemon
        }.inObjectScope(.container)

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

        container.register(VirtualTagDaemon.self) { r in
            let daemon = VirtualTagDaemonImpl()
            daemon.virtualService = r.resolve(VirtualService.self)
            daemon.settings = r.resolve(RuuviLocalSettings.self)
            daemon.virtualPersistence = r.resolve(VirtualPersistence.self)
            daemon.alertService = r.resolve(AlertService.self)
            daemon.virtualReactor = r.resolve(VirtualReactor.self)
            return daemon
        }.inObjectScope(.container)

        container.register(WebTagOperationsManager.self) { r in
            let manager = WebTagOperationsManager()
            manager.alertService = r.resolve(RuuviServiceAlert.self)
            manager.alertHandler = r.resolve(AlertService.self)
            manager.weatherProviderService = r.resolve(VirtualProviderService.self)
            manager.virtualStorage = r.resolve(VirtualStorage.self)
            manager.virtualPersistence = r.resolve(VirtualPersistence.self)
            return manager
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

        container.register(UserPropertiesService.self) { r in
            let service = UserPropertiesServiceImpl()
            service.ruuviStorage = r.resolve(RuuviStorage.self)
            service.settings = r.resolve(RuuviLocalSettings.self)
            return service
        }

        container.register(UniversalLinkCoordinator.self, factory: { r in
            let coordinator = UniversalLinkCoordinatorImpl()
            let router = UniversalLinkRouterImpl()
            coordinator.ruuviUser = r.resolve(RuuviUser.self)
            coordinator.router = router
            return coordinator
        })
    }
}
