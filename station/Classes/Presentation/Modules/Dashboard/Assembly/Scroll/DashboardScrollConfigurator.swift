import Foundation

class DashboardScrollConfigurator {
    func configure(view: DashboardScrollViewController) {
        let router = DashboardRouter()
        router.transitionHandler = view
        
        let presenter = DashboardPresenter()
        presenter.router = router
        presenter.view = view
        
        view.output = presenter
    }
}
