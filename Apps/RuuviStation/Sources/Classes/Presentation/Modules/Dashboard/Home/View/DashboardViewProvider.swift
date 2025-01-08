import SwiftUI
import UIKit
import RuuviOntology

// MARK: - Enhanced DashboardViewState
class DashboardViewState: ObservableObject {
    @Published var items: [CardsViewModel] = []
    @Published var isUpdating: Bool = false
    @Published var dashboardViewType: DashboardType = .simple
}
