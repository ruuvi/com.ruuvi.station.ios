import Swinject
import BTKit

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
            manager.alertService = r.resolve(AlertService.self)
            manager.settings = r.resolve(Settings.self)
            manager.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
            manager.virtualTagTrunk = r.resolve(VirtualTagTrunk.self)
            manager.idPersistence = r.resolve(IDPersistence.self)
            manager.errorPresenter = r.resolve(ErrorPresenter.self)
            return manager
        }.inObjectScope(.container)

        container.register(LocationManager.self) { _ in
            let manager = LocationManagerImpl()
            return manager
        }

        container.register(PermissionsManager.self) { r in
            let manager = PermissionsManagerImpl()
            manager.locationManager = r.resolve(LocationManager.self)
            return manager
        }.inObjectScope(.container)

        container.register(PushNotificationsManager.self) { _ in
            let manager = PushNotificationsManagerImpl()
            return manager
        }

        container.register(DiffCalculator.self) { _ in
            let diffCalculator = DiffCalculatorImpl()
            return diffCalculator
        }
    }
}
