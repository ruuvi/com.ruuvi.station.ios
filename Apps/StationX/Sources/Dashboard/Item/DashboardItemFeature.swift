import BTKit
import Combine
import ComposableArchitecture
import Foundation

@Reducer
struct DashboardItemFeature {
    @ObservableState
    struct State: Hashable, Identifiable {
        var id: String { latest.uuid }
        var latest: RuuviTag
        var records: [Record] = []
    }

    struct Record: Hashable, Identifiable {
        var id: String {
            value.uuid
        }
        var date: Date
        var value: RuuviTag
    }

    enum Action {
        case didTap
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .didTap:
                return .none
            }
        }
    }
}
