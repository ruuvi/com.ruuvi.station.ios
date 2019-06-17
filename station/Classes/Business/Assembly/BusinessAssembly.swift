import Swinject

class BusinessAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(RuuviTagDaemon.self) { r in
            let daemon = RuuviTagDaemonBackgroundWorker()
            daemon.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
            return daemon
        }.inObjectScope(.container)
        
    }
}
