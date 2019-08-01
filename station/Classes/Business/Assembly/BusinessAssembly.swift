import Swinject
import BTKit

class BusinessAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(AppStateService.self) { r in
            let service = AppStateServiceImpl()
            service.ruuviTagDaemon = r.resolve(RuuviTagDaemon.self)
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
        
        container.register(RuuviTagDaemon.self) { r in
            let daemon = RuuviTagDaemonRealmBTKit()
            daemon.scanner = r.resolve(BTScanner.self)
            daemon.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
            return daemon
        }.inObjectScope(.container)
        
        
        container.register(RuuviTagService.self) { r in
            let service = RuuviTagServiceImpl()
            service.calibrationService = r.resolve(CalibrationService.self)
            service.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
            service.backgroundPersistence = r.resolve(BackgroundPersistence.self)
            return service
        }
        
        container.register(WeatherProviderService.self) { r in
            let service = WeatherProviderServiceImpl()
            service.owmApi = r.resolve(OpenWeatherMapAPI.self)
            service.locationManager = r.resolve(LocationManager.self)
            return service
        }
        
        container.register(WebTagService.self) { r in
            let service = WebTagServiceImpl()
            service.webTagPersistence = r.resolve(WebTagPersistence.self)
            return service
        }
    }
}
