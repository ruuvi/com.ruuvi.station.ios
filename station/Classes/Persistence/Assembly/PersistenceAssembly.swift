import Swinject
import RuuviContext
import RuuviStorage
import RuuviPersistence
import RuuviReactor
import RuuviLocal
import RuuviPool

class PersistenceAssembly: Assembly {
    // swiftlint:disable:next function_body_length
    func assemble(container: Container) {
        container.register(CalibrationPersistence.self) { _ in
            let persistence = CalibrationPersistenceUserDefaults()
            return persistence
        }

        container.register(RealmContextFactory.self) { _ in
            let factory = RealmContextFactoryImpl()
            return factory
        }.inObjectScope(.container)

        container.register(RealmContext.self) { r in
            let factory = r.resolve(RealmContextFactory.self)!
            return factory.create()
        }.inObjectScope(.container)

        container.register(RuuviLocalConnections.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalConnections()
        }

        container.register(RuuviLocalImages.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalImages()
        }

        container.register(RuuviLocalSyncState.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalSyncState()
        }.inObjectScope(.container)

        container.register(RuuviPersistenceFactory.self) { _ in
            return RuuviPersistenceFactoryImpl()
        }

        container.register(RuuviPoolFactory.self) { _ in
            return RuuviPoolFactoryCoordinator()
        }

        container.register(RuuviPool.self) { r in
            let factory = r.resolve(RuuviPoolFactory.self)!
            let realm = r.resolve(RuuviPersistence.self, name: "realm")!
            let sqlite = r.resolve(RuuviPersistence.self, name: "sqlite")!
            let localIDs = r.resolve(RuuviLocalIDs.self)!
            let localSettings = r.resolve(RuuviLocalSettings.self)!
            let localConnections = r.resolve(RuuviLocalConnections.self)!
            return factory.create(
                sqlite: sqlite,
                realm: realm,
                idPersistence: localIDs,
                settings: localSettings,
                connectionPersistence: localConnections
            )
        }

        container.register(RuuviReactorFactory.self) { _ in
            return RuuviReactorFactoryImpl()
        }

        container.register(RuuviReactor.self) { r in
            let factory = r.resolve(RuuviReactorFactory.self)!
            let sqliteContext = r.resolve(SQLiteContext.self)!
            let realmContext = r.resolve(RealmContext.self)!
            let sqltePersistence = r.resolve(RuuviPersistence.self, name: "sqlite")!
            let realmPersistence = r.resolve(RuuviPersistence.self, name: "realm")!
            return factory.create(
                sqliteContext: sqliteContext,
                realmContext: realmContext,
                sqlitePersistence: sqltePersistence,
                realmPersistence: realmPersistence
            )
        }.inObjectScope(.container)

        container.register(RuuviStorageFactory.self) { _ in
            let factory = RuuviStorageFactoryCoordinator()
            return factory
        }

        container.register(RuuviPersistence.self, name: "realm") { r in
            let context = r.resolve(RealmContext.self)!
            let factory = r.resolve(RuuviPersistenceFactory.self)!
            return factory.create(realm: context)
        }.inObjectScope(.container)

        container.register(RuuviPersistence.self, name: "sqlite") { r in
            let context = r.resolve(SQLiteContext.self)!
            let factory = r.resolve(RuuviPersistenceFactory.self)!
            return factory.create(sqlite: context)
        }.inObjectScope(.container)

        container.register(RuuviStorage.self) { r in
            let factory = r.resolve(RuuviStorageFactory.self)!
            let sqlite = r.resolve(RuuviPersistence.self, name: "sqlite")!
            let realm = r.resolve(RuuviPersistence.self, name: "realm")!
            return factory.create(realm: realm, sqlite: sqlite)
        }.inObjectScope(.container)

        container.register(RuuviLocalFactory.self) { _ in
            let factory = RuuviLocalFactoryUserDefaults()
            return factory
        }

        container.register(RuuviLocalSettings.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalSettings()
        }

        container.register(RuuviLocalIDs.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalIDs()
        }

        container.register(SQLiteContextFactory.self) { _ in
            let factory = SQLiteContextFactoryGRDB()
            return factory
        }

        container.register(SQLiteContext.self) { r in
            let factory = r.resolve(SQLiteContextFactory.self)!
            return factory.create()
        }.inObjectScope(.container)

        container.register(WebTagPersistence.self) { r in
            let persistence = WebTagPersistenceRealm()
            persistence.context = r.resolve(RealmContext.self)
            persistence.settings = r.resolve(RuuviLocalSettings.self)
            return persistence
        }

        container.register(WebTagPersistenceRealm.self) { r in
            let persistence = WebTagPersistenceRealm()
            persistence.context = r.resolve(RealmContext.self)
            return persistence
        }

        container.register(LocationPersistence.self, factory: { _ in
            let persistence = LocationPersistenceImpl()
            return persistence
        })
    }
}
