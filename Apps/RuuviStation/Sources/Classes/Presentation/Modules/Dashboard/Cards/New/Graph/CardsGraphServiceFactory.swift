import Foundation
import Swinject
import RuuviLocal
import RuuviOntology
import RuuviService
import RuuviStorage
import RuuviReactor
import RuuviPool
import RuuviPresenters
import BTKit

// MARK: - Graph Data Service Factory

protocol CardsGraphServiceFactory {
    func createGraphDataService(tagDataService: RuuviTagDataService) -> RuuviTagGraphDataService
    func createPresenter(
        view: CardsGraphViewInput
    ) -> CardsGraphPresenter
}

final class CardsGraphServiceFactoryImpl: CardsGraphServiceFactory {

    private let resolver: Resolver

    init(resolver: Resolver) {
        self.resolver = resolver
    }

    func createGraphDataService(
        tagDataService: RuuviTagDataService
    ) -> RuuviTagGraphDataService {
        return RuuviTagGraphDataServiceImpl(
            ruuviStorage: resolver.resolve(RuuviStorage.self)!,
            ruuviReactor: resolver.resolve(RuuviReactor.self)!,
            ruuviPool: resolver.resolve(RuuviPool.self)!,
            settings: resolver.resolve(RuuviLocalSettings.self)!,
            measurementService: resolver.resolve(RuuviServiceMeasurement.self)!,
            tagDataService: tagDataService,
            alertService: resolver.resolve(RuuviServiceAlert.self)!,
            gattService: resolver.resolve(GATTService.self)!,
            exportService: resolver.resolve(RuuviServiceExport.self)!,
            cloudSyncService: resolver.resolve(RuuviServiceCloudSync.self)!,
            ruuviSensorRecords: resolver.resolve(RuuviServiceSensorRecords.self)!,
            featureToggleService: resolver.resolve(FeatureToggleService.self)!,
            localSyncState: resolver.resolve(RuuviLocalSyncState.self)!,
            ruuviAppSettingsService: resolver.resolve(RuuviServiceAppSettings.self)!
        )
    }

    func createPresenter(
        view: CardsGraphViewInput
    ) -> CardsGraphPresenter {

        let r = AppAssembly.shared.assembler.resolver
        let presenter = CardsGraphPresenter()
        let interactor = TagChartsViewInteractor()

        presenter.view = view
        presenter.errorPresenter = resolver.resolve(ErrorPresenter.self)
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.foreground = r.resolve(BTForeground.self)
        presenter.ruuviReactor = r.resolve(RuuviReactor.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.alertPresenter = r.resolve(AlertPresenter.self)
        presenter.measurementService = r.resolve(RuuviServiceMeasurement.self)
        presenter.exportService = r.resolve(RuuviServiceExport.self)
        presenter.alertService = r.resolve(RuuviServiceAlert.self)
        presenter.background = r.resolve(BTBackground.self)
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
        interactor.presenter = presenter

        return presenter
    }
}
