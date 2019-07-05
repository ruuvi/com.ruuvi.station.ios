import Swinject

class CoreAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(PermissionsManager.self) { (r)  in
            let manager = PermissionsManagerImpl()
            return manager
        }.inObjectScope(.container)
        
    }
}
