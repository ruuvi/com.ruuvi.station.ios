import Swinject

class TankAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviTagTank.self) { r in
            let tank = RuuviTagTankCoordinator()
            tank.realm = r.resolve(RuuviTagPersistenceRealm.self)
            tank.sqlite = r.resolve(RuuviTagPersistenceSQLite.self)
            return tank
        }
    }
}
