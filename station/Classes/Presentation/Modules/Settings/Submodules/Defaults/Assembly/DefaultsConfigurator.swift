import Foundation
import RuuviLocal

class DefaultsConfigurator {
    func configure(view: DefaultsViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = DefaultsRouter()
        router.transitionHandler = view

        let presenter = DefaultsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(RuuviLocalSettings.self)

        view.output = presenter
    }
}
