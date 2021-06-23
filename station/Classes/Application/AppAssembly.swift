import Swinject
import RuuviLocal
import RuuviPool
import RuuviContext
import RuuviVirtual
import RuuviStorage
import RuuviService
import RuuviDFU
import RuuviMigration
#if canImport(RuuviDFUImpl)
import RuuviDFUImpl
#endif
#if canImport(RuuviMigrationImpl)
import RuuviMigrationImpl
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
