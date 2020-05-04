import Swinject

class PersistenceAssembly: Assembly {
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

        container.register(RealmContext.self) { _ in
            let context = RealmContextImpl()
            return context
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

        container.register(SQLiteContext.self) { _ in
            let context = SQLiteContextGRDB()
            return context
        }.inObjectScope(.container)

        container.register(WebTagPersistence.self) { r in
            let persistence = WebTagPersistenceRealm()
            persistence.context = r.resolve(RealmContext.self)
            return persistence
        }
    }
}
