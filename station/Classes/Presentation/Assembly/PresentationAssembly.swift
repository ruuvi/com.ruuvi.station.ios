import Swinject

class PresentationAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(ActivityPresenter.self) { r in
            let presenter = ActivityPresenterRuuviLogo()
            return presenter
        }
        
        container.register(ErrorPresenter.self) { r in
            let presenter = ErrorPresenterAlert()
            return presenter
        }
    }
}
