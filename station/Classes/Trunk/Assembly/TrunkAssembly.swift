import Swinject

class TrunkAssembly: Assembly {
    func assemble(container: Container) {
        container.register(VirtualTagTrunk.self) { r in
            let trunk = VirtualTagTrunkCoordinator()
            trunk.realm = r.resolve(WebTagPersistenceRealm.self)
            return trunk
        }
    }
}
