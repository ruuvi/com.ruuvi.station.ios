import Swinject
import BTKit

class CoreAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(BTForeground.self) { r in
            return BTKit.foreground
        }.inObjectScope(.container)
        
        container.register(BTBackground.self) { r in
            return BTKit.background
        }.inObjectScope(.container)
        
        container.register(LocalNotificationsManager.self) { r in
            let manager = LocalNotificationsManagerImpl()
            manager.realmContext = r.resolve(RealmContext.self)
            return manager
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
