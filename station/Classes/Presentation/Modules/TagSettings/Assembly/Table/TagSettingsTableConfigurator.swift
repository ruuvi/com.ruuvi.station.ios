import Foundation

class TagSettingsTableConfigurator {
    func configure(view: TagSettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = TagSettingsRouter()
        router.transitionHandler = view
        
        let presenter = TagSettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.backgroundPersistence = r.resolve(BackgroundPersistence.self)
        
        view.output = presenter
    }
}
