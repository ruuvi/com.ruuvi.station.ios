import SwiftUI
import RuuviOntology
import RuuviLocal

class DashboardViewState: ObservableObject {
    @Published var dashboardType: DashboardType = .simple
    @Published var cardTapAction: DashboardTapActionType = .card
}
