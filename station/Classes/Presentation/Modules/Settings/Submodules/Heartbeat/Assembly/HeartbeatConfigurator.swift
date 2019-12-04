import Foundation

class HeartbeatConfigurator {
    func configure(view: HeartbeatViewController) {
        let router = HeartbeatRouter()
        router.transitionHandler = view

        let presenter = HeartbeatPresenter()
        presenter.router = router
        presenter.view = view

        view.output = presenter
    }
}
