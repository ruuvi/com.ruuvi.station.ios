import Foundation

class SettingsTableConfigurator {
    func configure(view: SettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = SettingsRouter()
        router.transitionHandler = view

        let presenter = SettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.settings = r.resolve(Settings.self)
        presenter.ruuviTagReactor = r.resolve(RuuviTagReactor.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.alertService = r.resolve(AlertService.self)
        presenter.realmContext = r.resolve(RealmContext.self)

        view.output = presenter
    }
}
