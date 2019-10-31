import Foundation

class TagActionsConfigurator {
    func configure(view: TagActionsViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = TagActionsRouter()
        router.transitionHandler = view
        
        let presenter = TagActionsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.gattService = r.resolve(GATTService.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        
        view.output = presenter
    }
}
