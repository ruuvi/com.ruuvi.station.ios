import Foundation
import RuuviStorage

class TagsManagerConfigurator {
    func configure(view: TagsManagerViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = TagsManagerRouter()
        let presenter = TagsManagerPresenter()

        router.transitionHandler = view

        presenter.view = view
        presenter.router = router
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.alertPresenter = r.resolve(AlertPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.keychainService = r.resolve(KeychainService.self)
        presenter.ruuviTagTank = r.resolve(RuuviTagTank.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.userApiService = r.resolve(RuuviNetworkUserApi.self)

        view.output = presenter
    }
}
