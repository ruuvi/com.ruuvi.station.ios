import Foundation

class WebTagSettingsTableConfigurator {
    func configure(view: WebTagSettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = WebTagSettingsRouter()
        router.transitionHandler = view
        
        let presenter = WebTagSettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.backgroundPersistence = r.resolve(BackgroundPersistence.self)
        
        view.output = presenter
    }
}
