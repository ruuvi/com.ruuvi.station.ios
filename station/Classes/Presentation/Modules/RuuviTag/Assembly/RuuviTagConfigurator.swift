import Foundation

class RuuviTagConfigurator {
    func configure(view: RuuviTagViewController) {
        let router = RuuviTagRouter()
        router.transitionHandler = view
        
        let presenter = RuuviTagPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
