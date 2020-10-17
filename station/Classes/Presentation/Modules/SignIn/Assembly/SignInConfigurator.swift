import Foundation

class SignInConfigurator {
    func configure(view: SignInViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = SignInRouter()
        let presenter = SignInPresenter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router

        view.output = presenter
    }
}
