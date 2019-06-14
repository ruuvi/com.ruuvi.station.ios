import Foundation

class MenuTableConfigurator {
    func configure(view: MenuTableViewController) {
        let router = MenuRouter()
        router.transitionHandler = view
        
        let presenter = MenuPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
