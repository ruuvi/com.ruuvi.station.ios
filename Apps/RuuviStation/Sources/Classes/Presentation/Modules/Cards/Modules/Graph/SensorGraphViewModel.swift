import Combine
import SwiftUI

class SensorGraphViewModel: ObservableObject {
    // Published properties for UI
//    @Published var sensors: [SensorViewModel] = []
    @Published var activeCardIndex: Int = 0
    @Published var isLoading: Bool = false

    // Dependencies
    private let coordinator: CardsCoordinator
    private var cancellables = Set<AnyCancellable>()

    init(coordinator: CardsCoordinator) {
        self.coordinator = coordinator

//        // Subscribe to coordinator's publishers
//        coordinator.measurementTabData
//            .receive(on: RunLoop.main)
//            .sink { [weak self] sensors in
//                self?.sensors = sensors
//            }
//            .store(in: &cancellables)
//
//        coordinator.activeCardData
//            .receive(on: RunLoop.main)
//            .sink { [weak self] _ in
//                // Process active card data
//            }
//            .store(in: &cancellables)
    }

    // MARK: - User Actions

    func onCardSwiped(to index: Int) {
        activeCardIndex = index
//        coordinator.setActiveCard(index: index)
    }

    func refresh() {
        // Refresh data
    }
}
