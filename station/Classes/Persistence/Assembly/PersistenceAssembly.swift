import Swinject

class PersistenceAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(RealmContext.self) { r in
            let context = RealmContextImpl()
            return context
        }.inObjectScope(.container)
        
        container.register(RuuviTagPersistence.self) { r in
            let persistence = RuuviTagPersistenceRealm()
            persistence.context = r.resolve(RealmContext.self)
            return persistence
        }
        
        container.register(Settings.self) { r in
            let settings = SettingsUserDegaults()
            return settings
        }.inObjectScope(.container)
        
    }
}
