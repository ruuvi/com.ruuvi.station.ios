import Foundation

class WebTagSettingsTableConfigurator {
    func configure(view: WebTagSettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = WebTagSettingsRouter()
        router.transitionHandler = view

        let presenter = WebTagSettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.backgroundPersistence = r.resolve(BackgroundPersistence.self)
        presenter.photoPickerPresenter = r.resolve(PhotoPickerPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.webTagService = r.resolve(WebTagService.self)
        presenter.settings = r.resolve(Settings.self)
        presenter.alertService = r.resolve(AlertService.self)
        presenter.pushNotificationsManager = r.resolve(PushNotificationsManager.self)
        presenter.permissionsManager = r.resolve(PermissionsManager.self)
        
        view.output = presenter
    }
}
