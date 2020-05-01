import Swinject

class ReactorAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviTagReactor.self) { r in
            let reactor = RuuviTagReactorImpl()
            reactor.realm = r.resolve(RealmContext.self)
            reactor.sqlite = r.resolve(SQLiteContext.self)
            return reactor
        }.inObjectScope(.container)
    }
}
