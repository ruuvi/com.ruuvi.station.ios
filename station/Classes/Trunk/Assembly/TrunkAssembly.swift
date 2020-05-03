import Swinject

class TrunkAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviTagTrunk.self) { r in
            let trunk = RuuviTagTrunkCoordinator()
            trunk.realm = r.resolve(RuuviTagPersistenceRealm.self)
            trunk.sqlite = r.resolve(RuuviTagPersistenceSQLite.self)
            return trunk
        }
    }
}
