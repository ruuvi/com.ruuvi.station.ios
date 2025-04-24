import Combine
import SwiftUI
import RuuviOntology
import RuuviLocal

class CardsContainerViewModel: ObservableObject {
    // Published properties for UI
    @Published var cardViewModels: [CardsViewModel] = []
    @Published var activeCard: CardsViewModel?
    @Published var activeCardIndex: Int = 0
    @Published var isRefreshing: Bool = false
    @Published var alertState: AlertState?
    @Published var activeDialog: CardsDialogType?

    // Feature flags
    @Published var showNewMenu: Bool = false

    // Dependencies
    private let coordinator: CardsCoordinator
    private let flags: RuuviLocalFlags
    private var cancellables = Set<AnyCancellable>()

    init(coordinator: CardsCoordinator) {
        self.coordinator = coordinator

        let r = AppAssembly.shared.assembler.resolver
        self.flags = r.resolve(RuuviLocalFlags.self)!
        self.showNewMenu = flags.showNewMenuStyleOnSensorCardView

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
                self?.alertState = activeCard?.alertState
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

        coordinator.alertStateDidChange
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                print("Alert state did change: \(state)")
                self?.alertState = state
            }
            .store(in: &cancellables)

        coordinator.dialogTriggered
            .receive(on: RunLoop.main)
            .sink { [weak self] dialogType in
                self?.activeDialog = dialogType
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

    // MARK: - Legacy Toolbar Support
    func onAlertButtonTapped() {
        coordinator.onAlertButtonTapped()
    }

    func onSettingsButtonTapped() {
        coordinator.onSettingsButtonTapped()
    }
    // MARK: - Legacy Toolbar Support end
}
