import Foundation
import RuuviContext
import RuuviReactor
import RuuviLocal

class SettingsTableConfigurator {
    func configure(view: SettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = SettingsRouter()
        router.transitionHandler = view

        let presenter = SettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.alertService = r.resolve(AlertService.self)
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.featureToggleService = r.resolve(FeatureToggleService.self)

        view.output = presenter
    }
}
