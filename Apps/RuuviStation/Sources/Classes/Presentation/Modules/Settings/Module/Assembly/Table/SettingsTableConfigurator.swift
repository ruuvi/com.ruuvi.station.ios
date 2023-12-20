import Foundation
import RuuviContext
import RuuviLocal
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage
import RuuviUser

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
        presenter.alertService = r.resolve(RuuviServiceAlert.self)
        presenter.featureToggleService = r.resolve(FeatureToggleService.self)
        presenter.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)
        presenter.ruuviUser = r.resolve(RuuviUser.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)

        view.output = presenter
    }
}
