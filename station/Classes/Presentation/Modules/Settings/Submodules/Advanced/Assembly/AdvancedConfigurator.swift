import Foundation
import RuuviLocal

class AdvancedConfigurator {
    func configure(view: AdvancedTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = AdvancedRouter()
        router.transitionHandler = view

        let presenter = AdvancedPresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.featureToggleService = r.resolve(FeatureToggleService.self)
        view.output = presenter
    }
}
