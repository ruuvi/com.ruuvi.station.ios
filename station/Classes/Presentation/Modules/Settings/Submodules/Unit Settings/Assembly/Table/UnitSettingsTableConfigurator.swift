import Foundation
import RuuviLocal
import RuuviService

class UnitSettingsTableConfigurator {
    func configure(view: UnitSettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver
        let router = UnitSettingsRouter()
        router.transitionHandler = view

        let presenter = UnitSettingsPresenter()
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)
        presenter.view = view
        presenter.router = router

        view.output = presenter
        view.settings = r.resolve(RuuviLocalSettings.self)
    }
}
