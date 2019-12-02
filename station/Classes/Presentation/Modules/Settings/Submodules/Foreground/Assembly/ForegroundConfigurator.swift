import Foundation

class ForegroundConfigurator {
    func configure(view: ForegroundViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = ForegroundRouter()
        router.transitionHandler = view

        let presenter = ForegroundPresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(Settings.self)

        view.output = presenter
    }
}
