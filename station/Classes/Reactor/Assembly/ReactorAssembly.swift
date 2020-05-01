import Swinject

class ReactorAssembly: Assembly {
    func assemble(container: Container) {
        container.register(RuuviTagReactor.self) { r in
            let reactor = RuuviTagReactorImpl()
            reactor.rxSwift = RuuviTagReactorRxSwift()
            return reactor
        }.inObjectScope(.container)
    }
}
