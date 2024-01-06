import Foundation
import ComposableArchitecture

@Reducer
struct ChartFeature {
    @ObservableState
    struct State: Equatable {
        var records: [Record]
    }

    enum Action {
        case close
    }

    struct Record: Hashable, Identifiable {
        var id: UUID = UUID()
        var date: Date
        var value: Double
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .close:
                return .none
            }
        }
    }
}
