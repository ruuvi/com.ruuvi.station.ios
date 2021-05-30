import Foundation
import RuuviLocal

class WelcomeConfigurator {
    func configure(view: WelcomeViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = WelcomeRouter()
        router.transitionHandler = view

        let presenter = WelcomePresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(RuuviLocalSettings.self)

        view.output = presenter
    }
}
