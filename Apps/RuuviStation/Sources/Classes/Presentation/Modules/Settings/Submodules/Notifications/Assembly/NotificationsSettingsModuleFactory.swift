import RuuviLocal
import RuuviLocalization
import RuuviService
import RuuviUser
import UIKit

protocol NotificationsSettingsModuleFactory {
    func create() -> NotificationsSettingsTableViewController
}

final class NotificationsSettingsModuleFactoryImpl: NotificationsSettingsModuleFactory {
    func create() -> NotificationsSettingsTableViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = NotificationsSettingsTableViewController(
            title: RuuviLocalization.settingsAlertNotifications
        )
        let router = NotificationsSettingsRouter()
        router.transitionHandler = view

        let presenter = NotificationsSettingsPresenter()
        presenter.view = view
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.ruuviUser = r.resolve(RuuviUser.self)
        presenter.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)
        presenter.cloudNotificationService = r.resolve(RuuviServiceCloudNotification.self)
        presenter.router = router

        view.output = presenter
        return view
    }
}
