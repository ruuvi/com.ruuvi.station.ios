import Swinject

class PersistenceAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(AlertPersistence.self) { r in
            let persistence = AlertPersistenceUserDefaults()
            return persistence
        }
        
        container.register(BackgroundPersistence.self) { r in
            let persistence = BackgroundPersistenceUserDefaults()
            persistence.imagePersistence = r.resolve(ImagePersistence.self)
            return persistence
        }
        
        container.register(CalibrationPersistence.self) { r in
            let persistence = CalibrationPersistenceUserDefaults()
            return persistence
        }
        
        container.register(ConnectionPersistence.self) { r in
            let persistence = ConnectionPersistenceUserDefaults()
            return persistence
        }
        
        container.register(ImagePersistence.self) { r in
            let persistence = ImagePersistenceDocuments()
            return persistence
        }
        
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
        
        container.register(WebTagPersistence.self) { r in
            let persistence = WebTagPersistenceRealm()
            persistence.context = r.resolve(RealmContext.self)
            return persistence
        }
    }
}
