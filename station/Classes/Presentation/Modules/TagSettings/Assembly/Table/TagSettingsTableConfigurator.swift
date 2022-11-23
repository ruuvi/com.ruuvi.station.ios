import Foundation
import BTKit
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviUser
import RuuviCore
import RuuviPresenters
import RuuviPool
import RuuviNotifier

class TagSettingsTableConfigurator {
    func configure(view: TagSettingsTableViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = TagSettingsRouter()
        router.transitionHandler = view

        let presenter = TagSettingsPresenter()
        let interactor = TagSettingsInteractor()
        presenter.view = view
        presenter.router = router
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.photoPickerPresenter = r.resolve(PhotoPickerPresenter.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.alertService = r.resolve(RuuviServiceAlert.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.connectionPersistence = r.resolve(RuuviLocalConnections.self)
        presenter.pushNotificationsManager = r.resolve(RuuviCorePN.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.ruuviUser = r.resolve(RuuviUser.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.ruuviLocalImages = r.resolve(RuuviLocalImages.self)
        presenter.ruuviOwnershipService = r.resolve(RuuviServiceOwnership.self)
        presenter.ruuviSensorPropertiesService = r.resolve(RuuviServiceSensorProperties.self)
        presenter.featureToggleService = r.resolve(FeatureToggleService.self)
        presenter.exportService = r.resolve(RuuviServiceExport.self)
        presenter.ruuviPool = r.resolve(RuuviPool.self)
        presenter.localSyncState = r.resolve(RuuviLocalSyncState.self)
        presenter.alertHandler = r.resolve(RuuviNotifier.self)
        interactor.background = r.resolve(BTBackground.self)
        interactor.connectionPersistence = r.resolve(RuuviLocalConnections.self)
        presenter.interactor = interactor
        
        view.measurementService = r.resolve(RuuviServiceMeasurement.self)

        view.output = presenter
    }
}
