import Swinject
import BTKit

class CoreAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(BTConnection.self) { r in
            return BTKit.connection
        }.inObjectScope(.container)
        
        container.register(BTScanner.self) { r in
            return BTKit.scanner
        }.inObjectScope(.container)
        
        container.register(LocationManager.self) { r in
            let manager = LocationManagerImpl()
            return manager
        }
        
        container.register(PermissionsManager.self) { r in
            let manager = PermissionsManagerImpl()
            manager.locationManager = r.resolve(LocationManager.self)
            return manager
        }.inObjectScope(.container)
        
        container.register(PushNotificationsManager.self) { r in
            let manager = PushNotificationsManagerImpl()
            return manager
        }
    }
}
