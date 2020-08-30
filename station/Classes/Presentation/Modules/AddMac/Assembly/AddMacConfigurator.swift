import Foundation

class AddMacConfigurator {
    func configure(view: AddMacViewController) {
        // let r = AppAssembly.shared.assembler.resolver
        let router = AddMacRouter()
        let presenter = AddMacPresenter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router

        view.output = presenter
    }
}
