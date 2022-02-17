import Foundation
import RuuviLocal
import RuuviService

class ChartSettingsConfigurator {
    func configure(view: ChartSettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = ChartSettingsRouter()
        router.transitionHandler = view

        let presenter = ChartSettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.featureToggleService = r.resolve(FeatureToggleService.self)
        presenter.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)
        view.output = presenter
    }
}
