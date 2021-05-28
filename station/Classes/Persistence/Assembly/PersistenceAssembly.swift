import Swinject
import RuuviContext
import RuuviStorage

class PersistenceAssembly: Assembly {
// swiftlint:disable:next function_body_length
    func assemble(container: Container) {

        container.register(AlertPersistence.self) { _ in
            let persistence = AlertPersistenceUserDefaults()
            return persistence
        }

        container.register(BackgroundPersistence.self) { r in
            let persistence = BackgroundPersistenceUserDefaults()
            persistence.imagePersistence = r.resolve(ImagePersistence.self)
            return persistence
        }

        container.register(CalibrationPersistence.self) { _ in
            let persistence = CalibrationPersistenceUserDefaults()
            return persistence
        }

        container.register(ConnectionPersistence.self) { _ in
            let persistence = ConnectionPersistenceUserDefaults()
            return persistence
        }

        container.register(IDPersistence.self) { _ in
            return IDPersistenceUserDefaults()
        }

        container.register(ImagePersistence.self) { _ in
            let persistence = ImagePersistenceDocuments()
            return persistence
        }

        container.register(KeychainService.self) { r in
            let persistence = KeychainServiceImpl()
            persistence.settings = r.resolve(Settings.self)
            return persistence
        }.inObjectScope(.container)

        container.register(NetworkPersistence.self) { _ in
            let persistence = NetworkPersistenceImpl()
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

        container.register(RuuviStorageFactory.self) { _ in
            let factory = RuuviStorageFactoryCoordinator()
            return factory
        }

        container.register(RuuviStorage.self) { r in
            let realm = r.resolve(RealmContext.self)!
            let sqlite = r.resolve(SQLiteContext.self)!
            let factory = r.resolve(RuuviStorageFactory.self)!
            return factory.create(realm: realm, sqlite: sqlite)
        }.inObjectScope(.container)

        container.register(RuuviTagPersistence.self) { r in
            let persistence = RuuviTagPersistenceRealm()
            persistence.context = r.resolve(RealmContext.self)
            return persistence
        }

        container.register(RuuviTagPersistenceSQLite.self) { r in
            let context = r.resolve(SQLiteContext.self)!
            let persistence = RuuviTagPersistenceSQLite(database: context.database)
            return persistence
        }

        container.register(RuuviTagPersistenceRealm.self) { r in
            let persistence = RuuviTagPersistenceRealm()
            persistence.context = r.resolve(RealmContext.self)
            return persistence
        }

        container.register(Settings.self) { _ in
            let settings = SettingsUserDegaults()
            return settings
        }.inObjectScope(.container)

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
            persistence.settings = r.resolve(Settings.self)
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
