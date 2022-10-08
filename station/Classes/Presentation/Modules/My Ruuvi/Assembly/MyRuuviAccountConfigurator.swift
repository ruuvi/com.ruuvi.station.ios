import Foundation
import RuuviUser
import RuuviService
import RuuviPresenters
import RuuviCloud

class MyRuuviAccountConfigurator {
    func configure(view: MyRuuviAccountViewController) {
        let r = AppAssembly.shared.assembler.resolver
        let router = MyRuuviAccountRouter()
        router.transitionHandler = view

        let presenter = MyRuuviAccountPresenter()
        presenter.view = view
        presenter.router = router
        presenter.ruuviCloud = r.resolve(RuuviCloud.self)
        presenter.ruuviUser = r.resolve(RuuviUser.self)
        presenter.alertPresenter = r.resolve(AlertPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.authService = r.resolve(RuuviServiceAuth.self)
        view.output = presenter
    }
}