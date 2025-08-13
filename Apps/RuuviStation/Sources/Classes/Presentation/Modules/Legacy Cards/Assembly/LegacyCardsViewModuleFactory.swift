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

protocol LegacyCardsViewModuleFactory {
    func create() -> LegacyCardsViewController
}

final class CardsViewModuleFactoryImpl: LegacyCardsViewModuleFactory {
    func create() -> LegacyCardsViewController {
        let r = AppAssembly.shared.assembler.resolver

        let view = LegacyCardsViewController()

        let router = CardsRouter()
        router.transitionHandler = view

        let presenter = LegacyCardsPresenter()
        presenter.router = router
        presenter.view = view
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
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

        let interactor = CardsInteractor()
        interactor.background = r.resolve(BTBackground.self)
        interactor.connectionPersistence = r.resolve(RuuviLocalConnections.self)
        interactor.ruuviPool = r.resolve(RuuviPool.self)
        presenter.interactor = interactor

        view.measurementService = r.resolve(RuuviServiceMeasurement.self)
        view.output = presenter

        return view
    }
}
