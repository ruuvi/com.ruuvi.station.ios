import Foundation

class MenuTableConfigurator {
    func configure(view: MenuTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = MenuRouter()
        router.transitionHandler = view

        let presenter = MenuPresenter()
        presenter.userApi = r.resolve(RuuviNetworkUserApi.self)
        presenter.view = view
        presenter.router = router

        view.output = presenter
    }
}
