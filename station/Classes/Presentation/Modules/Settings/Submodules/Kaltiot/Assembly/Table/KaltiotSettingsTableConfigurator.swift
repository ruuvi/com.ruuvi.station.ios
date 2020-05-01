import Foundation

class KaltiotSettingsTableConfigurator {
    func configure(view: KaltiotSettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = KaltiotSettingsRouter()
        router.transitionHandler = view

        let presenter = KaltiotSettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.keychainService = r.resolve(KeychainService.self)
        presenter.ruuviNetworkKaltiot = r.resolve(RuuviNetworkKaltiot.self)

        view.output = presenter
    }
}
