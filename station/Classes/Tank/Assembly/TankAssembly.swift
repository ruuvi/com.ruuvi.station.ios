import Swinject
import RuuviPersistence
import RuuviLocal

class TankAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviTagTank.self) { r in
            let tank = RuuviTagTankCoordinator()
            tank.realm = r.resolve(RuuviPersistence.self, name: "realm")
            tank.sqlite = r.resolve(RuuviPersistence.self, name: "sqlite")
            tank.idPersistence = r.resolve(RuuviLocalIDs.self)
            tank.settings = r.resolve(RuuviLocalSettings.self)
            tank.sensorService = r.resolve(SensorService.self)
            tank.connectionPersistence = r.resolve(RuuviLocalConnections.self)
            return tank
        }

        container.register(VirtualTagTank.self) { r in
            let tank = VirtualTagTankCoordinator()
            tank.realm = r.resolve(WebTagPersistenceRealm.self)
            return tank
        }
    }
}
