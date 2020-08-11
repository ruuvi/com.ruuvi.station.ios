import Swinject

class TankAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviTagTank.self) { r in
            let tank = RuuviTagTankCoordinator()
            tank.realm = r.resolve(RuuviTagPersistenceRealm.self)
            tank.sqlite = r.resolve(RuuviTagPersistenceSQLite.self)
            tank.idPersistence = r.resolve(IDPersistence.self)
            tank.settings = r.resolve(Settings.self)
            tank.backgroundPersistence = r.resolve(BackgroundPersistence.self)
            tank.connectionPersistence = r.resolve(ConnectionPersistence.self)
            return tank
        }

        container.register(VirtualTagTank.self) { r in
            let tank = VirtualTagTankCoordinator()
            tank.realm = r.resolve(WebTagPersistenceRealm.self)
            return tank
        }
    }
}
