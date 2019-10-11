import Foundation

class DaemonsConfigurator {
    func configure(view: DaemonsViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = DaemonsRouter()
        router.transitionHandler = view
        
        let presenter = DaemonsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(Settings.self)
        
        view.output = presenter
    }
}
