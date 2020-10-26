import Foundation

class TagsManagerConfigurator {
    func configure(view: TagsManagerViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = TagsManagerRouter()
        let presenter = TagsManagerPresenter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.keychainService = r.resolve(KeychainService.self)
        presenter.ruuviTagTank = r.resolve(RuuviTagTank.self)
        presenter.ruuviTagTrunk = r.resolve(RuuviTagTrunk.self)
        presenter.userApiService = r.resolve(RuuviNetworkUserApi.self)

        view.output = presenter
    }
}
