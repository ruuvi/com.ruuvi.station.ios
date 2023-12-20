import Foundation
import RuuviLocal

class HeartbeatConfigurator {
    func configure(view: HeartbeatViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = HeartbeatRouter()
        router.transitionHandler = view

        let presenter = HeartbeatPresenter()
        presenter.router = router
        presenter.view = view
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.connectionPersistence = r.resolve(RuuviLocalConnections.self)

        view.output = presenter
    }
}
