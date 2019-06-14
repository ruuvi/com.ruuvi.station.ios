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
        
        container.register(ErrorPresenter.self) { r in
            let presenter = ErrorPresenterAlert()
            return presenter
        }
        
    }
}
