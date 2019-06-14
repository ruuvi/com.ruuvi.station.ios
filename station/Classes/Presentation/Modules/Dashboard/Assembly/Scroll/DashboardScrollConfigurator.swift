import Foundation

class DashboardScrollConfigurator {
    func configure(view: DashboardScrollViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = DashboardRouter()
        router.transitionHandler = view
        
        let presenter = DashboardPresenter()
        presenter.router = router
        presenter.view = view
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        
        view.output = presenter
    }
}
