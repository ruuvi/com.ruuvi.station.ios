import Swinject

class TrunkAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviTagTrunk.self) { r in
            let trunk = RuuviTagTrunkCoordinator()
            trunk.realm = r.resolve(RuuviTagPersistenceRealm.self)
            trunk.sqlite = r.resolve(RuuviTagPersistenceSQLite.self)
            trunk.settings = r.resolve(Settings.self)
            return trunk
        }

        container.register(VirtualTagTrunk.self) { r in
            let trunk = VirtualTagTrunkCoordinator()
            trunk.realm = r.resolve(WebTagPersistenceRealm.self)
            return trunk
        }
    }
}
