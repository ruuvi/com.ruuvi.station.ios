import BTKit
import RuuviContext
import RuuviCore
import RuuviDaemon
import RuuviLocal
import RuuviNotifier
import RuuviPool
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage
import RuuviUser
import UIKit

protocol NewCardsViewModuleFactory {
    func create() -> NewCardsViewProvider
}

final class NewCardsViewModuleFactoryImpl: NewCardsViewModuleFactory {
    func create() -> NewCardsViewProvider {
        let r = AppAssembly.shared.assembler.resolver

        let viewProvider = NewCardsViewProvider()

//        let router = CardsRouter()
//        router.transitionHandler = view
//
        let presenter = NewCardsPresenter()
        let interactor = NewCardsInteractor()

//        presenter.router = router
        presenter.view = viewProvider
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.flags = r.resolve(RuuviLocalFlags.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.alertService = r.resolve(RuuviServiceAlert.self)
        presenter.alertHandler = r.resolve(RuuviNotifier.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.background = r.resolve(BTBackground.self)
        presenter.connectionPersistence = r.resolve(RuuviLocalConnections.self)
        presenter.featureToggleService = r.resolve(FeatureToggleService.self)
        presenter.ruuviSensorPropertiesService = r.resolve(RuuviServiceSensorProperties.self)
        presenter.localSyncState = r.resolve(RuuviLocalSyncState.self)
        presenter.ruuviStorage = r.resolve(RuuviStorage.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.permissionsManager = r.resolve(RuuviCorePermission.self)
        presenter.measurementService = r.resolve(RuuviServiceMeasurement.self)
        presenter.interactor = interactor

        interactor.gattService = r.resolve(GATTService.self)
        interactor.settings = r.resolve(RuuviLocalSettings.self)
        interactor.exportService = r.resolve(RuuviServiceExport.self)
        interactor.ruuviReactor = r.resolve(RuuviReactor.self)
        interactor.ruuviPool = r.resolve(RuuviPool.self)
        interactor.ruuviStorage = r.resolve(RuuviStorage.self)
        interactor.cloudSyncService = r.resolve(RuuviServiceCloudSync.self)
        interactor.ruuviSensorRecords = r.resolve(RuuviServiceSensorRecords.self)
        interactor.featureToggleService = r.resolve(FeatureToggleService.self)
        interactor.localSyncState = r.resolve(RuuviLocalSyncState.self)
        interactor.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)
        interactor.flags = r.resolve(RuuviLocalFlags.self)
        interactor.presenter = presenter

        viewProvider.output = presenter

        return viewProvider
    }
}
