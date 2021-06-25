import Swinject
import BTKit
import RuuviStorage
import RuuviLocal
import RuuviCore
import RuuviService
import RuuviVirtual
import RuuviNotification
#if canImport(RuuviNotificationLocal)
import RuuviNotificationLocal
#endif
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
#if canImport(RuuviServiceMeasurement)
import RuuviServiceMeasurement
#endif

class CoreAssembly: Assembly {
    // swiftlint:disable:next function_body_length
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

        container.register(RuuviNotificationLocal.self) { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let ruuviStorage = r.resolve(RuuviStorage.self)!
            let virtualTagTrunk = r.resolve(VirtualStorage.self)!
            let idPersistence = r.resolve(RuuviLocalIDs.self)!
            let ruuviAlertService = r.resolve(RuuviServiceAlert.self)!
            let manager = RuuviNotificationLocalImpl(
                ruuviStorage: ruuviStorage,
                virtualTagTrunk: virtualTagTrunk,
                idPersistence: idPersistence,
                settings: settings,
                ruuviAlertService: ruuviAlertService
            )
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

        container.register(RuuviServiceMeasurement.self, factory: { r in
            let settings = r.resolve(RuuviLocalSettings.self)!
            let service = RuuviServiceMeasurementImpl(
                settings: settings,
                emptyValueString: "N/A".localized(),
                percentString: "%".localized()
            )
            return service
        })
    }
}
