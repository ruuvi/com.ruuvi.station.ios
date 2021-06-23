import Swinject
import BTKit
import RuuviStorage
import RuuviLocal
import RuuviCore
import RuuviService
import RuuviVirtual
#if canImport(RuuviCoreImage)
import RuuviCoreImage
#endif
#if canImport(RuuviCoreLocation)
import RuuviCoreLocation
#endif
#if canImport(RuuviLocationService)
import RuuviLocationService
#endif
#if canImport(RuuviCorePN)
import RuuviCorePN
#endif
#if canImport(RuuviCorePermission)
import RuuviCorePermission
#endif

class CoreAssembly: Assembly {
    func assemble(container: Container) {
        container.register(BTForeground.self) { _ in
            return BTKit.foreground
        }.inObjectScope(.container)

        container.register(BTBackground.self) { _ in
            return BTKit.background
        }.inObjectScope(.container)

        container.register(InfoProvider.self) { _ in
            let provider = InfoProviderImpl()
            return provider
        }

        container.register(LocalNotificationsManager.self) { r in
            let manager = LocalNotificationsManagerImpl()
            manager.settings = r.resolve(RuuviLocalSettings.self)
            manager.ruuviStorage = r.resolve(RuuviStorage.self)
            manager.virtualTagTrunk = r.resolve(VirtualStorage.self)
            manager.idPersistence = r.resolve(RuuviLocalIDs.self)
            manager.errorPresenter = r.resolve(ErrorPresenter.self)
            manager.ruuviAlertService = r.resolve(RuuviServiceAlert.self)
            return manager
        }.inObjectScope(.container)

        container.register(RuuviCoreLocation.self) { _ in
            let manager = RuuviCoreLocationImpl()
            return manager
        }

        container.register(RuuviCorePermission.self) { r in
            let locationManager = r.resolve(RuuviCoreLocation.self)!
            let manager = RuuviCorePermissionImpl(locationManager: locationManager)
            return manager
        }.inObjectScope(.container)

        container.register(RuuviCorePN.self) { _ in
            let manager = RuuviCorePNImpl()
            return manager
        }

        container.register(RuuviCoreImage.self) { _ in
            return RuuviCoreImageImpl()
        }

        container.register(MeasurementsService.self, factory: { r in
            let settings = r.resolve(RuuviLocalSettings.self)
            let service = MeasurementsServiceImpl()
            service.settings = settings
            return service
        })
    }
}
