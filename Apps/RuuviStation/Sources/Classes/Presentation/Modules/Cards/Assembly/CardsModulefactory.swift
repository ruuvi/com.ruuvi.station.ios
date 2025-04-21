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
        let coordinator = createCoordinator(
            transitionHandler: transitionHandler
        )

        coordinator.configure(
            selectedCard: selectedCard,
            viewModels: viewModels,
            ruuviTagSensors: ruuviTagSensors,
            sensorSettings: sensorSettings
        )

        let container = createDIContainer(with: coordinator)
        let tabsView = CardsContainerView(
            container: container,
            initialTab: selectedTab ?? .measurement
        )
        return UIHostingController(rootView: tabsView)
    }

    // MARK: - Private Methods

    private func createCoordinator(transitionHandler: UIViewController?) -> CardsCoordinator {
        return CardsCoordinator(transitionHandler: transitionHandler)
    }

    private func createDIContainer(with coordinator: CardsCoordinator) -> DIContainer {
        let container = DIContainer()

        // Register coordinator
        container.register(coordinator)

        // Register view models
        container.register(CardsContainerViewModel(coordinator: coordinator))
        container.register(SensorMeasurementViewModel(coordinator: coordinator))
        container.register(SensorGraphViewModel(coordinator: coordinator))
        container.register(SensorAlertsViewModel(coordinator: coordinator))
        container.register(SensorSettingsViewModel(coordinator: coordinator))

        return container
    }
}
