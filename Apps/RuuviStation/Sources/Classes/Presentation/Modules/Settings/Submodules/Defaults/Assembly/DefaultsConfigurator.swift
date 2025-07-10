import Foundation
import RuuviLocal
import RuuviUser

class DefaultsConfigurator {
    func configure(view: DefaultsViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = DefaultsRouter()
        router.transitionHandler = view

        let presenter = DefaultsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.flags = r.resolve(RuuviLocalFlags.self)
        presenter.ruuviUser = r.resolve(RuuviUser.self)

        view.output = presenter
    }
}
