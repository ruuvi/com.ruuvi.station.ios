import Foundation

class AddMacModalConfigurator {
    func configure() {
        let r = AppAssembly.shared.assembler.resolver

        let view = AddMacModalViewController()
        let router = AddMacModalRouter()
        let presenter = AddMacModalPresenter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router

        view.output = presenter
    }
}
