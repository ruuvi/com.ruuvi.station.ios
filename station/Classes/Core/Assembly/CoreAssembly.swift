import Swinject
import BTKit

class CoreAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(BTScanner.self) { r in
            return Ruuvi.scanner
        }.inObjectScope(.container)
        
        container.register(PermissionsManager.self) { (r)  in
            let manager = PermissionsManagerImpl()
            return manager
        }.inObjectScope(.container)
        
    }
}
