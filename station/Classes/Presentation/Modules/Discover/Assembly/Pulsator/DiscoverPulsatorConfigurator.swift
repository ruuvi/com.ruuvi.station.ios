import Foundation

class DiscoverPulsatorConfigurator {
    func configure(view: DiscoverPulsatorViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = DiscoverRouter()
        router.transitionHandler = view
        
        let presenter = DiscoverPresenter()
        presenter.view = view
        presenter.router = router
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.ruuviTagPersistence = r.resolve(RuuviTagPersistence.self)
        
        view.output = presenter
    }
}
