import UIKit
import RuuviLocal
import RuuviService

protocol NotificationsSettingsModuleFactory {
    func create() -> NotificationsSettingsTableViewController
}

final class NotificationsSettingsModuleFactoryImpl: NotificationsSettingsModuleFactory {
    func create() -> NotificationsSettingsTableViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = NotificationsSettingsTableViewController(
            title: "settings_alert_notifications".localized()
        )
        let router = NotificationsSettingsRouter()
        router.transitionHandler = view

        let presenter = NotificationsSettingsPresenter()
        presenter.view = view
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)
        presenter.cloudNotificationService = r.resolve(RuuviServiceCloudNotification.self)
        presenter.router = router

        view.output = presenter
        return view
    }
}
