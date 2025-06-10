import SwiftUI
import Foundation
import RuuviOntology
import Combine

// MARK: - Enhanced DashboardViewState
class DashboardViewState: ObservableObject {
    @Published var items: [CardsViewModel] = []
    @Published var isUpdating: Bool = false
    @Published var dashboardViewType: DashboardType = .simple
    @Published var dashboardTapActionType: DashboardTapActionType = .card
    @Published var dashboardSortingType: DashboardSortingType = .alphabetical
    @Published var shouldShowSignInBanner: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var showNoSensorsMessage: Bool = false

    // Store cancellables for individual view model observations
    private var viewModelCancellables: [String: Set<AnyCancellable>] = [:]

    func updateItems(_ newItems: [CardsViewModel]) {
        DispatchQueue.main.async { [weak self] in
            self?.items = newItems
            self?.setupViewModelObservations()
        }
    }

    private func setupViewModelObservations() {
        // Clear existing observations
        viewModelCancellables.removeAll()

        // Set up observation for each view model
        for viewModel in items {
            guard let id = viewModel.id else { continue }

            var cancellables = Set<AnyCancellable>()

            // Observe changes in the view model
            viewModel.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    // Propagate the change to our own objectWillChange
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)

            viewModelCancellables[id] = cancellables
        }
    }

    func updateDashboardType(_ type: DashboardType) {
        DispatchQueue.main.async { [weak self] in
            self?.dashboardViewType = type
        }
    }

    func updateRefreshState(_ isRefreshing: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isRefreshing = isRefreshing
        }
    }

    func updateNoSensorsMessage(_ show: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.showNoSensorsMessage = show
        }
    }

    func updateTapActionType(_ type: DashboardTapActionType) {
        DispatchQueue.main.async { [weak self] in
            self?.dashboardTapActionType = type
        }
    }

    func updateSortingType(_ type: DashboardSortingType) {
        DispatchQueue.main.async { [weak self] in
            self?.dashboardSortingType = type
        }
    }

    func updateSignInBanner(_ show: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.shouldShowSignInBanner = show
        }
    }
    
    // MARK: - Single Item Update for Performance Optimization
    func updateSingleItem(_ updatedViewModel: CardsViewModel) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Find and update the specific view model
            if let index = self.items.firstIndex(where: { $0.id == updatedViewModel.id }) {
                self.items[index] = updatedViewModel
                // This will trigger the @Published update for just this item
                self.objectWillChange.send()
                
                // Update the individual observation for this view model
                if let id = updatedViewModel.id {
                    self.setupSingleViewModelObservation(for: updatedViewModel, id: id)
                }
            }
        }
    }
    
    // MARK: - Helper Methods for Single View Model Observation
    private func setupSingleViewModelObservation(for viewModel: CardsViewModel, id: String) {
        // Clear existing observation for this view model
        viewModelCancellables[id]?.removeAll()
        
        var cancellables = Set<AnyCancellable>()
        
        // Observe changes in the view model
        viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Propagate the change to our own objectWillChange
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        viewModelCancellables[id] = cancellables
    }
}

class DashboardViewActions: ObservableObject {
    let cardDidTap = PassthroughSubject<CardsViewModel, Never>()
    let cardDidTriggerOpenCardImageView = PassthroughSubject<CardsViewModel, Never>()
    let cardDidTriggerChart = PassthroughSubject<CardsViewModel, Never>()
    let cardDidTriggerSettings = PassthroughSubject<CardsViewModel, Never>()
    let cardDidTriggerChangeBackground = PassthroughSubject<CardsViewModel, Never>()
    let cardDidTriggerRename = PassthroughSubject<CardsViewModel, Never>()
    let cardDidTriggerShare = PassthroughSubject<CardsViewModel, Never>()
    let cardDidTriggerRemove = PassthroughSubject<CardsViewModel, Never>()
    let cardDidTriggerMoveUp = PassthroughSubject<CardsViewModel, Never>()
    let cardDidTriggerMoveDown = PassthroughSubject<CardsViewModel, Never>()
    let cardDidReorder = PassthroughSubject<[CardsViewModel], Never>()
}

// MARK: - Dashboard Bridge
class DashboardBridge: NSObject, DashboardViewInput {

    let state: DashboardViewState
    weak var presenter: DashboardPresenterRefactored?

    init(state: DashboardViewState) {
        self.state = state
        super.init()
    }

    // MARK: - DashboardViewInput Implementation
    var viewModels: [CardsViewModel] {
        get { state.items }
        set { state.updateItems(newValue) }
    }

    var dashboardType: DashboardType! {
        get { state.dashboardViewType }
        set { state.updateDashboardType(newValue) }
    }

    var dashboardTapActionType: DashboardTapActionType! {
        get { state.dashboardTapActionType }
        set { state.updateTapActionType(newValue) }
    }

    var dashboardSortingType: DashboardSortingType! {
        get { state.dashboardSortingType }
        set { state.updateSortingType(newValue) }
    }

    var shouldShowSignInBanner: Bool {
        get { state.shouldShowSignInBanner }
        set { state.updateSignInBanner(newValue) }
    }

    var isRefreshing: Bool {
        get { state.isRefreshing }
        set { state.updateRefreshState(newValue) }
    }

    // MARK: - DashboardViewInput Methods
    func showBluetoothDisabled(userDeclined: Bool) {
        DispatchQueue.main.async {
            // You can add a @Published property to state for this if needed
            // For now, we'll use NotificationCenter or delegate pattern
            NotificationCenter.default.post(
                name: .showBluetoothDisabled,
                object: nil,
                userInfo: ["userDeclined": userDeclined]
            )
        }
    }

    func showKeepConnectionDialogChart(for viewModel: CardsViewModel) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .showKeepConnectionDialogChart,
                object: viewModel
            )
        }
    }

    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .showKeepConnectionDialogSettings,
                object: viewModel
            )
        }
    }

    func showSensorNameRenameDialog(for viewModel: CardsViewModel, sortingType: DashboardSortingType) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .showSensorNameRenameDialog,
                object: viewModel,
                userInfo: ["sortingType": sortingType]
            )
        }
    }
    
    func showSensorSortingResetConfirmationDialog() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .showSensorSortingResetConfirmationDialog, object: nil)
        }
    }
    
    func showAlreadyLoggedInAlert(with email: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .showAlreadyLoggedInAlert,
                object: nil,
                userInfo: ["email": email]
            )
        }
    }
    
    func showNoSensorsAddedMessage(show: Bool) {
        state.updateNoSensorsMessage(show)
    }
    
    // MARK: - Single View Model Update
    func applyUpdate(to viewModel: CardsViewModel) {
        state.updateSingleItem(viewModel)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let showBluetoothDisabled = Notification.Name("showBluetoothDisabled")
    static let showKeepConnectionDialogChart = Notification.Name("showKeepConnectionDialogChart")
    static let showKeepConnectionDialogSettings = Notification.Name("showKeepConnectionDialogSettings")
    static let showSensorNameRenameDialog = Notification.Name("showSensorNameRenameDialog")
    static let showSensorSortingResetConfirmationDialog = Notification.Name("showSensorSortingResetConfirmationDialog")
    static let showAlreadyLoggedInAlert = Notification.Name("showAlreadyLoggedInAlert")
    static let dashboardPullToRefresh = Notification.Name("dashboardPullToRefresh")
    static let dashboardCardTapped = Notification.Name("dashboardCardTapped")
}
