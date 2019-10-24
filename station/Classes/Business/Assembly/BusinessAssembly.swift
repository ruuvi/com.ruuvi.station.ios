import Swinject
import BTKit

class BusinessAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(AppStateService.self) { r in
            let service = AppStateServiceImpl()
            service.settings = r.resolve(Settings.self)
            service.advertisementDaemon = r.resolve(RuuviTagAdvertisementDaemon.self)
            service.connectionDaemon = r.resolve(RuuviTagConnectionDaemon.self)
            service.webTagDaemon = r.resolve(WebTagDaemon.self)
            service.heartbeatDaemon = r.resolve(RuuviTagHeartbeatDaemon.self)
            return service
        }.inObjectScope(.container)
        
        container.register(CalibrationService.self) { r in
            let service = CalibrationServiceImpl()
            service.calibrationPersistence = r.resolve(CalibrationPersistence.self)
            service.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
            return service
        }
        
        container.register(LocationService.self) { r in
            let service = LocationServiceApple()
            return service
        }
        
        container.register(MigrationManager.self) { r in
            let manager = MigrationManagerToVIPER()
            manager.backgroundPersistence = r.resolve(BackgroundPersistence.self)
            manager.settings = r.resolve(Settings.self)
            return manager
        }
        
        container.register(RuuviTagAdvertisementDaemon.self) { r in
            let daemon = RuuviTagAdvertisementDaemonBTKit()
            daemon.settings = r.resolve(Settings.self)
            daemon.foreground = r.resolve(BTForeground.self)
            daemon.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
            return daemon
        }
        
        container.register(RuuviTagConnectionDaemon.self) { r in
            let daemon = RuuviTagConnectionDaemonBTKit()
            daemon.settings = r.resolve(Settings.self)
            daemon.foreground = r.resolve(BTForeground.self)
            daemon.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
            return daemon
        }.inObjectScope(.container)
        
        container.register(RuuviTagHeartbeatDaemon.self) { r in
            let service = RuuviTagHeartbeatDaemonBTKit()
            service.background = r.resolve(BTBackground.self)
            service.localNotificationsManager = r.resolve(LocalNotificationsManager.self)
            service.connectionPersistence = r.resolve(ConnectionPersistence.self)
            service.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
            return service
        }.inObjectScope(.container)
        
        container.register(RuuviTagService.self) { r in
            let service = RuuviTagServiceImpl()
            service.calibrationService = r.resolve(CalibrationService.self)
            service.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
            service.backgroundPersistence = r.resolve(BackgroundPersistence.self)
            service.background = r.resolve(BTBackground.self)
            return service
        }
        
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
            return daemon
        }
        
        container.register(WebTagService.self) { r in
            let service = WebTagServiceImpl()
            service.webTagPersistence = r.resolve(WebTagPersistence.self)
            service.weatherProviderService = r.resolve(WeatherProviderService.self)
            return service
        }
    }
}
