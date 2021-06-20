import Foundation
import RuuviLocal
import RuuviService

class WebTagSettingsTableConfigurator {
    func configure(view: WebTagSettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = WebTagSettingsRouter()
        router.transitionHandler = view

        let presenter = WebTagSettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.photoPickerPresenter = r.resolve(PhotoPickerPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.webTagService = r.resolve(VirtualService.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.alertService = r.resolve(RuuviServiceAlert.self)
        presenter.pushNotificationsManager = r.resolve(PushNotificationsManager.self)
        presenter.permissionsManager = r.resolve(PermissionsManager.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.ruuviSensorPropertiesService = r.resolve(RuuviServiceSensorProperties.self)

        view.output = presenter
    }
}
