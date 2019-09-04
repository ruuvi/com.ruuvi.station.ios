import Foundation

class SettingsTableConfigurator {
    func configure(view: SettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = SettingsRouter()
        router.transitionHandler = view
        
        let presenter = SettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(Settings.self)
        
        view.output = presenter
    }
}
