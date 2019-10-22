import Foundation

class BackgroundConfigurator {
    func configure(view: BackgroundViewController) {
        let router = BackgroundRouter()
        router.transitionHandler = view
        
        let presenter = BackgroundPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
