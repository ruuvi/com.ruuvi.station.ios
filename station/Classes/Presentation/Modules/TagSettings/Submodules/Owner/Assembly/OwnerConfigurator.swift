import Foundation

final class OwnerConfigurator {
    func configure(view: OwnerViewController) {
        let router = OwnerRouter()
        router.transitionHandler = view

        let presenter = OwnerPresenter()
        presenter.view = view
        presenter.router = router

        view.output = presenter
    }
}
