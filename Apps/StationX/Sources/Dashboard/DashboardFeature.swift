import BTKit
import Combine
import ComposableArchitecture
import Foundation

@Reducer
struct DashboardFeature {
    @ObservableState
    struct State: Equatable {
        var sortedTags: IdentifiedArrayOf<DashboardItemFeature.State> = []
        var uniqueTags: Set<DashboardItemFeature.State> = []
        var bufferedTags: Set<RuuviTag> = []
        var isMenuOpen: Bool = false
    }

    enum Action {
        case toggleMenu
        case startListening
        case stopListening
        case received(RuuviTag)
        case emitBufferedTags
        case item(IdentifiedActionOf<DashboardItemFeature>)
    }

    enum CancelID {
        case listen
        case emitTimer
    }

    var body: some ReducerOf<Self> {
        Reduce {
            state,
            action in
            switch action {
            case .toggleMenu:
                state.isMenuOpen.toggle()
                return .none
            case .startListening:
                let listeningEffect = BTForeground.publisher.ruuviTag
                    .map(Action.received)
                let timerEffect = Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
                    .map { _ in Action.emitBufferedTags }
                return .merge(
                    .publisher { listeningEffect }.cancellable(id: CancelID.listen),
                    .publisher { timerEffect }.cancellable(id: CancelID.emitTimer)
                )
            case let .received(ruuviTag):
                state.bufferedTags.update(with: ruuviTag)
                return .none
            case .emitBufferedTags:
                state.bufferedTags.forEach { ruuviTag in
                    if var uniqueTag = state.uniqueTags.first(where: { $0.latest.id == ruuviTag.id }) {
                        state.uniqueTags.remove(uniqueTag)
                        uniqueTag.latest = ruuviTag
                        uniqueTag.records.append(
                            DashboardItemFeature.Record(date: Date(), value: ruuviTag)
                        )
                        state.uniqueTags.update(with: uniqueTag)
                    } else {
                        state.uniqueTags.insert(DashboardItemFeature.State(latest: ruuviTag))
                    }
                }

                state.sortedTags = IdentifiedArrayOf(
                    uniqueElements: state.uniqueTags.sorted(by: { $0.latest.rssi ?? 0 < $1.latest.rssi ?? 0})
                )
                state.bufferedTags.removeAll()
                return .none
            case .stopListening:
                state.bufferedTags.removeAll()
                return .merge(.cancel(id: CancelID.listen), .cancel(id: CancelID.emitTimer))
            case .item:
                return .none
            }
        }
        .forEach(\.sortedTags, action: \.item) {
            DashboardItemFeature()
        }
    }
}
