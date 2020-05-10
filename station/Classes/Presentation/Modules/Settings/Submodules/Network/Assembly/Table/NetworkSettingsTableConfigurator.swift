import Foundation

class NetworkSettingsTableConfigurator {
    func configure(view: NetworkSettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = NetworkSettingsRouter()
        router.transitionHandler = view

        let presenter = NetworkSettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.keychainService = r.resolve(KeychainService.self)
        presenter.ruuviNetworkKaltiot = r.resolve(RuuviNetworkKaltiot.self)
        presenter.settings = r.resolve(Settings.self)

        view.output = presenter
    }
}
