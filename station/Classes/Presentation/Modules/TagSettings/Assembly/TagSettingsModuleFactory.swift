import BTKit
import Foundation
import RuuviCore
import RuuviDaemon
import RuuviLocal
import RuuviNotifier
import RuuviOntology
import RuuviPool
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage
import RuuviUser
import UIKit

protocol TagSettingsModuleFactory {
    func create() -> TagSettingsViewController
}

final class TagSettingsModuleFactoryImpl: TagSettingsModuleFactory {
    func create() -> TagSettingsViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = TagSettingsViewController()
        let router = TagSettingsRouter()
        router.transitionHandler = view

        let presenter = TagSettingsPresenter()
        presenter.view = view
        presenter.router = router
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
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
        presenter.ruuviOwnershipService = r.resolve(RuuviServiceOwnership.self)
        presenter.ruuviSensorPropertiesService = r.resolve(RuuviServiceSensorProperties.self)
        presenter.featureToggleService = r.resolve(FeatureToggleService.self)
        presenter.exportService = r.resolve(RuuviServiceExport.self)
        presenter.ruuviPool = r.resolve(RuuviPool.self)
        presenter.localSyncState = r.resolve(RuuviLocalSyncState.self)
        presenter.alertHandler = r.resolve(RuuviNotifier.self)

        view.measurementService = r.resolve(RuuviServiceMeasurement.self)

        view.output = presenter

        return view
    }
}
