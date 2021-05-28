import Swinject
import RuuviPersistence
import RuuviLocal

class TankAssembly: Assembly {
    func assemble(container: Container) {
        container.register(VirtualTagTank.self) { r in
            let tank = VirtualTagTankCoordinator()
            tank.realm = r.resolve(WebTagPersistenceRealm.self)
            return tank
        }
    }
}
