import Foundation

class WebTagSettingsTableConfigurator {
    func configure(view: WebTagSettingsTableViewController) {
        let router = WebTagSettingsRouter()
        router.transitionHandler = view
        
        let presenter = WebTagSettingsPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
