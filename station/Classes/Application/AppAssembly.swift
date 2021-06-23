import Swinject
import RuuviLocal
import RuuviPool
import RuuviContext
import RuuviVirtual
import RuuviStorage
import RuuviService
import RuuviDFU
import RuuviMigration
import RuuviPersistence
import RuuviReactor
import SwinjectPropertyLoader
import RuuviCloud
import RuuviUser
#if canImport(RuuviCloudPure)
import RuuviCloudPure
#endif
#if canImport(RuuviVirtualOWM)
import RuuviVirtualOWM
#endif
#if canImport(RuuviContextRealm)
import RuuviContextRealm
#endif
#if canImport(RuuviContextSQLite)
import RuuviContextSQLite
#endif
#if canImport(RuuviPersistenceRealm)
import RuuviPersistenceRealm
#endif
#if canImport(RuuviPersistenceSQLite)
import RuuviPersistenceSQLite
#endif
#if canImport(RuuviStorageCoordinator)
import RuuviStorageCoordinator
#endif
#if canImport(RuuviPoolCoordinator)
import RuuviPoolCoordinator
#endif
#if canImport(RuuviLocalUserDefaults)
import RuuviLocalUserDefaults
#endif
#if canImport(RuuviPoolCoordinator)
import RuuviPoolCoordinator
#endif
#if canImport(RuuviReactorImpl)
import RuuviReactorImpl
#endif
#if canImport(RuuviDFUImpl)
import RuuviDFUImpl
#endif
#if canImport(RuuviMigrationImpl)
import RuuviMigrationImpl
#endif
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

final class AppAssembly {
    static let shared = AppAssembly()
    var assembler: Assembler

    init() {
        assembler = Assembler(
            [
                BusinessAssembly(),
                CoreAssembly(),
                MigrationAssembly(),
                NetworkingAssembly(),
                PersistenceAssembly(),
                PresentationAssembly(),
                DfuAssembly(),
                VirtualAssembly()
            ])
    }
}

private final class DfuAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviDFU.self) { _ in
            return RuuviDFUImpl.shared
        }.inObjectScope(.container)
    }
}

private final class MigrationAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviMigration.self, name: "realm") { r in
            let localImages = r.resolve(RuuviLocalImages.self)!
            let settings = r.resolve(RuuviLocalSettings.self)!
            return MigrationManagerToVIPER(localImages: localImages, settings: settings)
        }

        container.register(RuuviMigrationFactory.self) { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let idPersistence = r.resolve(RuuviLocalIDs.self)!
            let realmContext = r.resolve(RealmContext.self)!
            let ruuviPool = r.resolve(RuuviPool.self)!
            let virtualStorage = r.resolve(VirtualStorage.self)!
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let ruuviAlertService = r.resolve(RuuviServiceAlert.self)!
            let ruuviOffsetCalibrationService = r.resolve(RuuviServiceOffsetCalibration.self)!
            return RuuviMigrationFactoryImpl(
                settings: settings,
                idPersistence: idPersistence,
                realmContext: realmContext,
                ruuviPool: ruuviPool,
                virtualStorage: virtualStorage,
                ruuviStorage: ruuviStorage,
                ruuviAlertService: ruuviAlertService,
                ruuviOffsetCalibrationService: ruuviOffsetCalibrationService
            )
        }
    }
}

private final class PersistenceAssembly: Assembly {
    // swiftlint:disable:next function_body_length
    func assemble(container: Container) {
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
            return RuuviPersistenceRealm(context: context)
        }.inObjectScope(.container)

        container.register(RuuviPersistence.self, name: "sqlite") { r in
            let context = r.resolve(SQLiteContext.self)!
            return RuuviPersistenceSQLite(context: context)
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

    }
}

private final class NetworkingAssembly: Assembly {
    func assemble(container: Container) {
        let config = PlistPropertyLoader(bundle: .main, name: "Networking")
        try! container.applyPropertyLoader(config)

        container.register(OpenWeatherMapAPI.self) { r in
            let apiKey: String = r.property("Open Weather Map API Key")!
            let api = OpenWeatherMapAPIURLSession(apiKey: apiKey)
            return api
        }

        container.register(RuuviCloud.self) { r in
            let user = r.resolve(RuuviUser.self)!
            let baseUrlString: String = r.property("Ruuvi Cloud URL")!
            let baseUrl = URL(string: baseUrlString)!
            let cloud = r.resolve(RuuviCloudFactory.self)!.create(
                baseUrl: baseUrl,
                user: user
            )
            return cloud
        }

        container.register(RuuviCloudFactory.self) { _ in
            return RuuviCloudFactoryPure()
        }
    }
}

private final class VirtualAssembly: Assembly {
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
