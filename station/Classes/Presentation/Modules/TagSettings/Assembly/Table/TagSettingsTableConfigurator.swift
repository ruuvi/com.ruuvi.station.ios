import Foundation
import BTKit
import RuuviStorage
import RuuviReactor
import RuuviLocal

class TagSettingsTableConfigurator {
    func configure(view: TagSettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = TagSettingsRouter()
        router.transitionHandler = view

        let presenter = TagSettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.sensorService = r.resolve(SensorService.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.photoPickerPresenter = r.resolve(PhotoPickerPresenter.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.calibrationService = r.resolve(CalibrationService.self)
        presenter.alertService = r.resolve(AlertService.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.connectionPersistence = r.resolve(ConnectionPersistence.self)
        presenter.pushNotificationsManager = r.resolve(PushNotificationsManager.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.ruuviTagTank = r.resolve(RuuviTagTank.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.keychainService = r.resolve(KeychainService.self)
        presenter.ruuviNetwork = r.resolve(RuuviNetworkUserApi.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.backgroundPersistence = r.resolve(BackgroundPersistence.self)

        view.measurementService = r.resolve(MeasurementsService.self)

        view.output = presenter
    }
}
