import Foundation

class KaltiotPickerTableConfigurator {
    func configure(view: KaltiotPickerTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = KaltiotPickerRouter()
        router.transitionHandler = view

        let presenter = KaltiotPickerPresenter()
        presenter.view = view
        presenter.router = router
        presenter.keychainService = r.resolve(KeychainService.self)
        presenter.ruuviNetworkKaltiot = r.resolve(RuuviNetworkKaltiot.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        view.output = presenter
    }
}
