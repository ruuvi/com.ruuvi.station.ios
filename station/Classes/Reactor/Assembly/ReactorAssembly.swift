import Swinject

class ReactorAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviTagReactor.self) { r in
            let reactor = RuuviTagReactorImpl()
            reactor.realmContext = r.resolve(RealmContext.self)
            reactor.sqliteContext = r.resolve(SQLiteContext.self)
            reactor.realmPersistence = r.resolve(RuuviTagPersistenceRealm.self)
            reactor.sqlitePersistence = r.resolve(RuuviTagPersistenceSQLite.self)
            return reactor
        }.inObjectScope(.container)
    }
}
