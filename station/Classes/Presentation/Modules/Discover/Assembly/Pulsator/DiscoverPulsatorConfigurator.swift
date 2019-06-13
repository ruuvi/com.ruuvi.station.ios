import Foundation

class DiscoverPulsatorConfigurator {
    func configure(view: DiscoverPulsatorViewController) {
        let router = DiscoverRouter()
        router.transitionHandler = view
        
        let presenter = DiscoverPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
