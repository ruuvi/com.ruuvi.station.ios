import Swinject
import RuuviContext

class ReactorAssembly: Assembly {
    func assemble(container: Container) {
        container.register(VirtualTagReactor.self) { r in
            let reactor = VirtualTagReactorImpl()
            reactor.realmContext = r.resolve(RealmContext.self)
            reactor.realmPersistence = r.resolve(WebTagPersistence.self)
            return reactor
        }.inObjectScope(.container)
    }
}
