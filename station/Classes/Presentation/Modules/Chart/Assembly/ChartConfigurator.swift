import Foundation

class ChartConfigurator {
    func configure(view: ChartViewController) {
        let router = ChartRouter()
        router.transitionHandler = view
        
        let presenter = ChartPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
