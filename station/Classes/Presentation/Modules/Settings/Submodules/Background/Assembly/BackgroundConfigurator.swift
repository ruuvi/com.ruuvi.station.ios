import Foundation
import BTKit

class BackgroundConfigurator {
    func configure(view: BackgroundViewController) {
        let r = AppAssembly.shared.assembler.resolver
        
        let router = BackgroundRouter()
        router.transitionHandler = view
        
        let presenter = BackgroundPresenter()
        presenter.view = view
        presenter.router = router
        presenter.realmContext = r.resolve(RealmContext.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.heartbeatService = r.resolve(HeartbeatService.self)
        
        view.output = presenter
    }
}
