import Combine
import SwiftUI

class CardsContainerViewModel: ObservableObject {
    // Published properties for UI
    @Published var cardViewModels: [CardsViewModel] = []
    @Published var activeCard: CardsViewModel?
    @Published var activeCardIndex: Int = 0
    @Published var isRefreshing: Bool = false

    // Dependencies
    private let coordinator: CardsCoordinator
    private var cancellables = Set<AnyCancellable>()

    init(coordinator: CardsCoordinator) {
        self.coordinator = coordinator

        // Subscribe to coordinator's publishers
        coordinator.viewModelsData
            .receive(on: RunLoop.main)
            .sink { [weak self] viewModels in
                self?.cardViewModels = viewModels
            }
            .store(in: &cancellables)

        coordinator.activeCardData
            .receive(on: RunLoop.main)
            .sink { [weak self] activeCard in
                self?.activeCard = activeCard
            }
            .store(in: &cancellables)

        coordinator.activeCardIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] index in
                self?.activeCardIndex = index
            }
            .store(in: &cancellables)

        coordinator.cloudSyncInProgress
            .receive(on: RunLoop.main)
            .sink { [weak self] refreshing in
                self?.isRefreshing = refreshing
            }
            .store(in: &cancellables)
    }

    // MARK: - User Actions
    func onCardSwiped(to index: Int) {
        activeCardIndex = index
        coordinator.setActiveCardIndex(index)
    }

    func onBackButtonTapped() {
        coordinator.onBackButtonTapped()
    }
}
