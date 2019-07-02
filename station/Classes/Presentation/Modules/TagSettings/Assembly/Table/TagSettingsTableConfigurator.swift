import Foundation

class TagSettingsTableConfigurator {
    func configure(view: TagSettingsTableViewController) {
        let router = TagSettingsRouter()
        router.transitionHandler = view
        
        let presenter = TagSettingsPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
