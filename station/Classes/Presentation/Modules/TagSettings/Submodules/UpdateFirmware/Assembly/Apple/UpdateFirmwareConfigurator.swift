import Foundation

class UpdateFirmwareConfigurator: NSObject {
    func configure(view: UpdateFirmwareAppleViewController) {
        let router = UpdateFirmwareRouter()
        router.transitionHandler = view

        let presenter = UpdateFirmwarePresenter()
        presenter.view = view
        presenter.router = router

        view.output = presenter
    }
}
