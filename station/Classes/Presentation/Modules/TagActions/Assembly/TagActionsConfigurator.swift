import Foundation

class TagActionsConfigurator {
    func configure(view: TagActionsViewController) {
        let router = TagActionsRouter()
        router.transitionHandler = view
        
        let presenter = TagActionsPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
