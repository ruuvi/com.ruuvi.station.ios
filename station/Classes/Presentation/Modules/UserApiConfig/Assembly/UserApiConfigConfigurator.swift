import Foundation

class UserApiConfigConfigurator {
    func configure(view: UserApiConfigViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = UserApiConfigRouter()
        let presenter = UserApiConfigPresenter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.keychainService = r.resolve(KeychainService.self)
        presenter.userApiService = r.resolve(RuuviNetworkUserApi.self)

        view.output = presenter
    }
}
