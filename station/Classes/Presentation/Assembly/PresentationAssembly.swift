import Swinject

class PresentationAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(ActivityPresenter.self) { r in
            let presenter = ActivityPresenterRuuviLogo()
            return presenter
        }
        
    }
}
