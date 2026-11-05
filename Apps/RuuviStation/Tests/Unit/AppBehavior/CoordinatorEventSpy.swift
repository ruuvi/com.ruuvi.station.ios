import Foundation
@testable import station

final class CoordinatorEventSpy: RuuviTagServiceCoordinatorObserver {
    var events = [RuuviTagServiceCoordinatorEvent]()
    var allOnMainThread = true
    func coordinatorDidReceiveEvent(_ coordinator: RuuviTagServiceCoordinator, event: RuuviTagServiceCoordinatorEvent) {
        allOnMainThread = allOnMainThread && Thread.isMainThread
        events.append(event)
    }
    var lists: [([RuuviTagCardSnapshot], SnapshotUpdateReason, Bool)] {
        events.compactMap {
            guard case let .snapshotsUpdated(snapshots, reason, animation) = $0 else { return nil }
            return (snapshots, reason, animation)
        }
    }
    var types: [RuuviTagCoordinatorEventType] { events.map(\.eventType) }
}
