import Foundation

class DefaultsConfigurator {
    func configure(view: DefaultsViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = DefaultsRouter()
        router.transitionHandler = view
        
        let presenter = DefaultsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(Settings.self)
        
        view.output = presenter
    }
}
