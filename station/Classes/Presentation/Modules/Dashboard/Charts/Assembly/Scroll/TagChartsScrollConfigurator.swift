import Foundation

class TagChartsScrollConfigurator {
    func configure(view: TagChartsScrollViewController) {
        let router = TagChartsRouter()
        router.transitionHandler = view
        
        let presenter = TagChartsPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
