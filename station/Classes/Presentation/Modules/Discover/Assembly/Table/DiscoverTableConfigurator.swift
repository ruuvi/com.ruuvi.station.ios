import Foundation

class DiscoverTableConfigurator {
    func configure(view: DiscoverTableViewController) {
        let router = DiscoverRouter()
        router.transitionHandler = view
        
        let presenter = DiscoverPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
