import Foundation
import RuuviLocal

class LanguageTableConfigurator {
    func configure(view: LanguageTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = LanguageRouter()
        router.transitionHandler = view

        let presenter = LanguagePresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(RuuviLocalSettings.self)

        view.output = presenter
    }
}
