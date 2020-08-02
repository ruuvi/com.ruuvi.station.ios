import Foundation

class AddMacModalConfigurator {
    func configure(view: AddMacModalViewController) {
        // let r = AppAssembly.shared.assembler.resolver
        let router = AddMacModalRouter()
        let presenter = AddMacModalPresenter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router

        view.output = presenter
    }
}
