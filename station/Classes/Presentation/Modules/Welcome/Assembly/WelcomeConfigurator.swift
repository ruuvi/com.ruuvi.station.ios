import Foundation

class WelcomeConfigurator {
    func configure(view: WelcomeViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = WelcomeRouter()
        router.transitionHandler = view

        let presenter = WelcomePresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(Settings.self)

        view.output = presenter
    }
}
