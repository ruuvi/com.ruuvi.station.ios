import Foundation

class AboutConfigurator {
    func configure(view: AboutViewController) {
        let router = AboutRouter()
        router.transitionHandler = view
        
        let presenter = AboutPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
