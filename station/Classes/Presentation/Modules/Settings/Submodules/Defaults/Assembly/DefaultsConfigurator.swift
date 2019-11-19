import Foundation

class DefaultsConfigurator {
    func configure(view: DefaultsViewController) {
        let router = DefaultsRouter()
        router.transitionHandler = view
        
        let presenter = DefaultsPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
