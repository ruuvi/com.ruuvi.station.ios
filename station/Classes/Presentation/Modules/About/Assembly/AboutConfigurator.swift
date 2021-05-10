import Foundation

class AboutConfigurator {
    func configure(view: AboutViewController) {
        let r = AppAssembly.shared.assembler.resolver
        let router = AboutRouter()
        router.transitionHandler = view

        let presenter = AboutPresenter()
        presenter.view = view
        presenter.router = router
        presenter.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
        presenter.realmContext = r.resolve(RealmContext.self)

        view.output = presenter
    }
}
