import Foundation

class ChartConfigurator {
    func configure(view: ChartViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = ChartRouter()
        router.transitionHandler = view
        
        let presenter = ChartPresenter()
        presenter.view = view
        presenter.router = router
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        
        view.output = presenter
    }
}
