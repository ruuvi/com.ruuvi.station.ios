import Foundation

class TagChartsConfigurator {
    func configure(view: TagChartsViewController) {
        let router = TagChartsRouter()
        router.transitionHandler = view
        
        let presenter = TagChartsPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
