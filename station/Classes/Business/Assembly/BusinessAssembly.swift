import Swinject
import BTKit

// swiftlint:disable:next type_body_length
class BusinessAssembly: Assembly {

    // swiftlint:disable:next function_body_length
    func assemble(container: Container) {

        container.register(AlertService.self) { r in
            let service = AlertServiceImpl()
            service.alertPersistence = r.resolve(AlertPersistence.self)
            service.calibrationService = r.resolve(CalibrationService.self)
            return service
        }.inObjectScope(.container).initCompleted { (r, service) in
            // swiftlint:disable force_cast
            let s = service as! AlertServiceImpl
            // swiftlint:enable force_cast
            s.localNotificationsManager = r.resolve(LocalNotificationsManager.self)
        }

        container.register(AppStateService.self) { r in
            let service = AppStateServiceImpl()
            service.settings = r.resolve(Settings.self)
            service.advertisementDaemon = r.resolve(RuuviTagAdvertisementDaemon.self)
            service.propertiesDaemon = r.resolve(RuuviTagPropertiesDaemon.self)
            service.webTagDaemon = r.resolve(WebTagDaemon.self)
            service.pullNetworkTagDaemon = r.resolve(PullRuuviNetworkDaemon.self)
            service.heartbeatDaemon = r.resolve(RuuviTagHeartbeatDaemon.self)
            service.keychainService = r.resolve(KeychainService.self)
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
                service.ruuviTagNetworkOperationManager = r.resolve(RuuviNetworkTagOperationsManager.self)
                return service
            } else {
                let service = BackgroundTaskServiceiOS12()
                return service
            }
        }.inObjectScope(.container)

        container.register(CalibrationService.self) { r in
            let service = CalibrationServiceImpl()
            service.calibrationPersistence = r.resolve(CalibrationPersistence.self)
            return service
        }

        container.register(DataPruningOperationsManager.self) { r in
            let manager = DataPruningOperationsManager()
            manager.settings = r.resolve(Settings.self)
            manager.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
            manager.virtualTagTrunk = r.resolve(VirtualTagTrunk.self)
            manager.virtualTagTank = r.resolve(VirtualTagTank.self)
            manager.ruuviTagTank = r.resolve(RuuviTagTank.self)
            return manager
        }

        container.register(ExportService.self) { r in
            let service = ExportServiceTrunk()
            service.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
            service.measurementService = r.resolve(MeasurementsService.self)
            service.calibrationService = r.resolve(CalibrationService.self)
            return service
        }

        container.register(FeatureToggleService.self) { r in
            let service = FeatureToggleService()
            service.mainProvider = r.resolve(FirebaseRemoteConfigProvider.self)
            service.fallbackProvider = r.resolve(LocalFeatureToggleProvider.self)
            service.settings = r.resolve(Settings.self)
            return service
        }.inObjectScope(.container)

        container.register(FirebaseRemoteConfigProvider.self) { r in
            let provider = FirebaseRemoteConfigProvider()
            provider.remoteConfigService = r.resolve(RemoteConfigService.self)
            return provider
        }.inObjectScope(.container)

        container.register(GATTService.self) { r in
            let service = GATTServiceQueue()
            service.ruuviTagTank = r.resolve(RuuviTagTank.self)
            service.background = r.resolve(BTBackground.self)
            return service
        }.inObjectScope(.container)

        container.register(LocalFeatureToggleProvider.self) { _ in
            let provider = LocalFeatureToggleProvider()
            return provider
        }.inObjectScope(.container)

        container.register(LocationService.self) { r in
            let service = LocationServiceApple()
            service.locationPersistence = r.resolve(LocationPersistence.self)
            return service
        }

        container.register(MigrationManagerToVIPER.self) { r in
            let manager = MigrationManagerToVIPER()
            manager.backgroundPersistence = r.resolve(BackgroundPersistence.self)
            manager.settings = r.resolve(Settings.self)
            return manager
        }

        container.register(MigrationManagerToSQLite.self) { r in
            let manager = MigrationManagerToSQLite()
            manager.alertPersistence = r.resolve(AlertPersistence.self)
            manager.backgroundPersistence = r.resolve(BackgroundPersistence.self)
            manager.calibrationPersistence = r.resolve(CalibrationPersistence.self)
            manager.connectionPersistence = r.resolve(ConnectionPersistence.self)
            manager.idPersistence = r.resolve(IDPersistence.self)
            manager.settingsPersistence = r.resolve(Settings.self)
            manager.realmContext = r.resolve(RealmContext.self)
            manager.sqliteContext = r.resolve(SQLiteContext.self)
            manager.errorPresenter = r.resolve(ErrorPresenter.self)
            manager.ruuviTagTank = r.resolve(RuuviTagTank.self)
            return manager
        }

        container.register(MigrationManagerAlertService.self) { r in
            let manager = MigrationManagerAlertService()
            manager.alertService = r.resolve(AlertService.self)
            manager.alertPersistence = r.resolve(AlertPersistence.self)
            manager.realmContext = r.resolve(RealmContext.self)
            manager.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
            manager.settings = r.resolve(Settings.self)
            return manager
        }

        container.register(MigrationManagerToPrune240.self) { r in
            let manager = MigrationManagerToPrune240()
            manager.settings = r.resolve(Settings.self)
            return manager
        }

        container.register(PullWebDaemon.self) { r in
            let daemon = PullWebDaemonOperations()
            daemon.settings = r.resolve(Settings.self)
            daemon.webTagOperationsManager = r.resolve(WebTagOperationsManager.self)
            return daemon
        }.inObjectScope(.container)

        container.register(PullRuuviNetworkDaemon.self) { r in
            let daemon = PullRuuviNetworkDaemonOperation()
            daemon.settings = r.resolve(Settings.self)
            daemon.networkPersistance = r.resolve(NetworkPersistence.self)
            daemon.ruuviTagNetworkOperationsManager = r.resolve(RuuviNetworkTagOperationsManager.self)
            return daemon
        }.inObjectScope(.container)

        container.register(RemoteConfigService.self) { _ in
            let service = FirebaseRemoteConfigService()
            return service
        }.inObjectScope(.container)

        container.register(RuuviTagAdvertisementDaemon.self) { r in
            let daemon = RuuviTagAdvertisementDaemonBTKit()
            daemon.settings = r.resolve(Settings.self)
            daemon.foreground = r.resolve(BTForeground.self)
            daemon.ruuviTagTank = r.resolve(RuuviTagTank.self)
            daemon.ruuviTagReactor = r.resolve(RuuviTagReactor.self)
            return daemon
        }.inObjectScope(.container)

        container.register(RuuviTagHeartbeatDaemon.self) { r in
            let daemon = RuuviTagHeartbeatDaemonBTKit()
            daemon.background = r.resolve(BTBackground.self)
            daemon.localNotificationsManager = r.resolve(LocalNotificationsManager.self)
            daemon.connectionPersistence = r.resolve(ConnectionPersistence.self)
            daemon.ruuviTagTank = r.resolve(RuuviTagTank.self)
            daemon.ruuviTagReactor = r.resolve(RuuviTagReactor.self)
            daemon.alertService = r.resolve(AlertService.self)
            daemon.settings = r.resolve(Settings.self)
            daemon.pullWebDaemon = r.resolve(PullWebDaemon.self)
            return daemon
        }.inObjectScope(.container)

        container.register(NetworkService.self) { r in
            let service = NetworkServiceQueue()
            service.ruuviTagTank = r.resolve(RuuviTagTank.self)
            service.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
            let factory = RuuviNetworkFactory()
            factory.userApi = r.resolve(RuuviNetworkUserApi.self)
            service.ruuviNetworkFactory = factory
            service.networkPersistence = r.resolve(NetworkPersistence.self)
            service.settings = r.resolve(Settings.self)
            return service
        }.inObjectScope(.container)

        container.register(RuuviTagPropertiesDaemon.self) { r in
            let daemon = RuuviTagPropertiesDaemonBTKit()
            daemon.ruuviTagReactor = r.resolve(RuuviTagReactor.self)
            daemon.ruuviTagTank = r.resolve(RuuviTagTank.self)
            daemon.foreground = r.resolve(BTForeground.self)
            daemon.idPersistence = r.resolve(IDPersistence.self)
            daemon.realmPersistence = r.resolve(RuuviTagPersistenceRealm.self)
            daemon.sqiltePersistence = r.resolve(RuuviTagPersistenceSQLite.self)
            return daemon
        }.inObjectScope(.container)

        container.register(WeatherProviderService.self) { r in
            let service = WeatherProviderServiceImpl()
            service.owmApi = r.resolve(OpenWeatherMapAPI.self)
            service.locationManager = r.resolve(LocationManager.self)
            service.locationService = r.resolve(LocationService.self)
            return service
        }

        container.register(WebTagDaemon.self) { r in
            let daemon = WebTagDaemonImpl()
            daemon.webTagService = r.resolve(WebTagService.self)
            daemon.settings = r.resolve(Settings.self)
            daemon.webTagPersistence = r.resolve(WebTagPersistence.self)
            daemon.alertService = r.resolve(AlertService.self)
            return daemon
        }.inObjectScope(.container)

        container.register(WebTagOperationsManager.self) { r in
            let manager = WebTagOperationsManager()
            manager.alertService = r.resolve(AlertService.self)
            manager.weatherProviderService = r.resolve(WeatherProviderService.self)
            manager.webTagPersistence = r.resolve(WebTagPersistence.self)
            return manager
        }

        container.register(WebTagService.self) { r in
            let service = WebTagServiceImpl()
            service.webTagPersistence = r.resolve(WebTagPersistence.self)
            service.weatherProviderService = r.resolve(WeatherProviderService.self)
            return service
        }

        container.register(UserPropertiesService.self) { r in
            let service = UserPropertiesServiceImpl()
            service.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
            service.settings = r.resolve(Settings.self)
            return service
        }

        container.register(RuuviNetworkTagOperationsManager.self) { r in
            let service = RuuviNetworkTagOperationsManager()
            service.ruuviNetworkFactory = r.resolve(RuuviNetworkFactory.self)
            service.ruuviTagTank = r.resolve(RuuviTagTank.self)
            service.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
            service.keychainService = r.resolve(KeychainService.self)
            service.networkPersistance = r.resolve(NetworkPersistence.self)
            service.settings = r.resolve(Settings.self)
            return service
        }

        container.register(UniversalLinkCoordinator.self, factory: { r in
            let coordinator = UniversalLinkCoordinatorImpl()
            let router = UniversalLinkRouterImpl()
            coordinator.keychainService = r.resolve(KeychainService.self)
            coordinator.router = router
            return coordinator
        })
    }
}
