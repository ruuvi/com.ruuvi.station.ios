import SwiftUI
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
import Combine
import RuuviOntology

// MARK: - Factory Protocol

protocol CardsModuleFactory {
    func createTabsModule(
        selectedTab: CardsTabType?,
        selectedCard: CardsViewModel?,
        viewModels: [CardsViewModel],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        transitionHandler: UIViewController?
    ) -> UIViewController
}

// MARK: - Factory Implementation

final class CardsModuleFactoryImpl: CardsModuleFactory {
    func createTabsModule(
        selectedTab: CardsTabType? = .measurement,
        selectedCard: CardsViewModel? = nil,
        viewModels: [CardsViewModel],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        transitionHandler: UIViewController? = nil
    ) -> UIViewController {
        let router = CardsRouter()
        router.transitionHandler = transitionHandler

        let coordinator = CardsCoordinator(
            transitionHandler: transitionHandler,
            router: router
        )

        coordinator.configure(
            selectedCard: selectedCard,
            viewModels: viewModels,
            ruuviTagSensors: ruuviTagSensors,
            sensorSettings: sensorSettings
        )

        // TODO: Cleanup
        let interactor = NewCardsInteractor()
        let r = AppAssembly.shared.assembler.resolver
        interactor.gattService = r.resolve(GATTService.self)
        interactor.settings = r.resolve(RuuviLocalSettings.self)
        interactor.flags = r.resolve(RuuviLocalFlags.self)
        interactor.exportService = r.resolve(RuuviServiceExport.self)
        interactor.ruuviReactor = r.resolve(RuuviReactor.self)
        interactor.ruuviPool = r.resolve(RuuviPool.self)
        interactor.ruuviStorage = r.resolve(RuuviStorage.self)
        interactor.cloudSyncService = r.resolve(RuuviServiceCloudSync.self)
        interactor.ruuviSensorRecords = r.resolve(RuuviServiceSensorRecords.self)
        interactor.featureToggleService = r.resolve(FeatureToggleService.self)
        interactor.localSyncState = r.resolve(RuuviLocalSyncState.self)
        interactor.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)

        let container = createDIContainer(
            with: coordinator,
            graphInteractor: interactor
        )
        let tabsView = CardsContainerView(
            container: container,
            initialTab: selectedTab ?? .measurement
        )
        return UIHostingController(rootView: tabsView)
    }

    // MARK: - Private Methods

    private func createDIContainer(
        with coordinator: CardsCoordinator,
        graphInteractor: NewCardsInteractor
    ) -> DIContainer {
        let container = DIContainer()

        // Register coordinator
        container.register(coordinator)

        // Register view models
        container.register(CardsContainerViewModel(coordinator: coordinator))
        container.register(SensorMeasurementViewModel(coordinator: coordinator))
        container
            .register(
                SensorGraphContainerViewModel(
                    coordinator: coordinator,
                    interactor: graphInteractor
                )
            )
        container.register(SensorAlertsViewModel(coordinator: coordinator))
        container.register(SensorSettingsViewModel(coordinator: coordinator))

        return container
    }
}
