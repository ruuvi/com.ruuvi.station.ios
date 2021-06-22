import Swinject
import RuuviVirtual
import RuuviContext
import RuuviLocal
#if canImport(RuuviVirtualPersistence)
import RuuviVirtualPersistence
#endif
#if canImport(RuuviVirtualReactor)
import RuuviVirtualReactor
#endif
#if canImport(RuuviVirtualRepository)
import RuuviVirtualRepository
#endif
#if canImport(RuuviVirtualStorage)
import RuuviVirtualStorage
#endif

class VirtualAssembly: Assembly {
    func assemble(container: Container) {
        container.register(VirtualPersistence.self) { r in
            let context = r.resolve(RealmContext.self)!
            let settings = r.resolve(RuuviLocalSettings.self)!
            return VirtualPersistenceRealm(context: context, settings: settings)
        }

        container.register(VirtualReactor.self) { r in
            let context = r.resolve(RealmContext.self)!
            let persistence = r.resolve(VirtualPersistence.self)!
            return VirtualReactorImpl(context: context, persistence: persistence)
        }.inObjectScope(.container)

        container.register(VirtualRepository.self) { r in
            let persistence = r.resolve(VirtualPersistence.self)!
            return VirtualRepositoryCoordinator(persistence: persistence)
        }

        container.register(VirtualStorage.self) { r in
            let persistence = r.resolve(VirtualPersistence.self)!
            return VirtualStorageCoordinator(persistence: persistence)
        }
    }
}
