import Foundation
import SwiftUI
import UIKit
import RuuviOntology
import RuuviService
import Combine

// MARK: - Scroll Position Manager
class ScrollPositionManager: ObservableObject {
    @Published var currentPosition: String?
    var isScrolling: Bool = false
    private var lastKnownPositions: [String: Int] = [:]

    func updateScrolling(_ scrolling: Bool) {
        isScrolling = scrolling
    }

    func savePositions(items: [CardsViewModel]) {
        guard isScrolling else { return }
        lastKnownPositions = Dictionary(
            uniqueKeysWithValues: items.enumerated().map { ($0.element.id ?? "", $0.offset) }
        )
    }

    func calculateNewPosition(items: [CardsViewModel]) -> String? {
        guard isScrolling, let currentPosition = currentPosition else { return nil }

        if let currentIndex = lastKnownPositions[currentPosition] {
            let relativePosition = Double(currentIndex) / Double(lastKnownPositions.count)
            let newIndex = min(Int(relativePosition * Double(items.count)), items.count - 1)
            return items[newIndex].id
        }
        return currentPosition
    }
}

// MARK: - Enhanced DashboardViewState
class DashboardViewState: ObservableObject {
    @Published var items: [CardsViewModel] = []
    @Published var isUpdating: Bool = false
    @Published var dashboardViewType: DashboardType = .simple
    var scrollManager = ScrollPositionManager()

    private var updateQueue = DispatchQueue(label: "com.ruuvi.dashboard.updates")
    private var updateThreshold: TimeInterval = 0.1
    private var pendingUpdates: [CardsViewModel] = []

    func updateItems(_ newItems: [CardsViewModel], fromSync: Bool = false) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if self.scrollManager.isScrolling && fromSync {
                    self.handleSyncUpdate(newItems)
                } else {
                    self.applyRegularUpdate(newItems)
                }
            }
        }
    }

    private func handleSyncUpdate(_ newItems: [CardsViewModel]) {
        self.scrollManager.savePositions(items: items)

        withAnimation(.easeInOut(duration: 0.3)) {
            items = newItems
            if let newPosition = scrollManager.calculateNewPosition(items: newItems) {
                scrollManager.currentPosition = newPosition
            }
        }
    }

    private func applyRegularUpdate(_ newItems: [CardsViewModel]) {
        withAnimation(.easeInOut(duration: 0.3)) {
            items = newItems
        }
    }
}

class DashboardViewProvider: NSObject {

    // Public
    var output: DashboardViewOutput!
    var measurementService: RuuviServiceMeasurement!

    // MARK: DashboardViewInput
    var viewModels: [CardsViewModel] = [] {
        didSet {
            state.updateItems(viewModels)
        }
    }

    var dashboardType: DashboardType! {
        didSet {
            state.dashboardViewType = dashboardType
        }
    }

    var dashboardTapActionType: DashboardTapActionType! {
        didSet {

        }
    }

    var dashboardSortingType: DashboardSortingType! {
        didSet {

        }
    }

    var userSignedInOnce: Bool = false {
        didSet {

        }
    }

    var isAuthorized: Bool = false {
        didSet {

        }
    }

    var shouldShowSignInBanner: Bool = false {
        didSet {

        }
    }

    // MARK: Private
    private var state = DashboardViewState()

    override init() {
        super.init()
    }
}

extension DashboardViewProvider {
    func makeViewController() -> UIViewController {
        return UIHostingController(
            rootView: DashboardView(
                measurementService: measurementService
            ).environmentObject(state)
        )
    }
}

// MARK: DashboardViewInput
extension DashboardViewProvider: DashboardViewInput {

    func applyUpdate(to viewModel: CardsViewModel) {

    }

    func showNoSensorsAddedMessage(show: Bool) {

    }

    func showBluetoothDisabled(userDeclined: Bool) {

    }

    func showKeepConnectionDialogChart(for viewModel: CardsViewModel) {

    }

    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel) {

    }

    func showReverseGeocodingFailed() {

    }

    func showAlreadyLoggedInAlert(with email: String) {

    }

    func showSensorNameRenameDialog(
        for viewModel: CardsViewModel,
        sortingType: RuuviOntology.DashboardSortingType
    ) {

    }

    func showSensorSortingResetConfirmationDialog() {

    }
}
