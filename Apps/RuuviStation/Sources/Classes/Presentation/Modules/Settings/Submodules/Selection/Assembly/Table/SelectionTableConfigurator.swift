import Foundation
import RuuviLocal

class SelectionTableConfigurator {
    func configure(view: SelectionTableViewController) {
        let r = AppAssembly.shared.assembler.resolver
        let router = SelectionRouter()
        router.transitionHandler = view

        let presenter = SelectionPresenter()
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.view = view
        presenter.router = router

        view.output = presenter
        view.settings = r.resolve(RuuviLocalSettings.self)
    }
}
