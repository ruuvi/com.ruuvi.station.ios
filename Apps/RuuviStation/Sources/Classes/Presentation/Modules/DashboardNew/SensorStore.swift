import Foundation
import Combine
import Observation

typealias SensorStore = any SensorStoreProtocol

// MARK: - Factory for creating the appropriate store
@MainActor
struct SensorStoreFactory {
    static func create() -> any SensorStoreProtocol {
        if #available(iOS 17.0, *) {
            return ModernSensorStore()
        } else {
            return LegacySensorStore()
        }
    }
}

// MARK: - Protocol for both implementations
@MainActor
protocol SensorStoreProtocol: AnyObject {
    var snapshots: [SensorSnapshot] { get }
    func apply(_ snap: SensorSnapshot)
    func remove(_ id: String)
    func reorder(by newOrder: [SensorSnapshot.ID])
    func commitImmediate()
}

// MARK: - iOS 16 and below - ObservableObject
@MainActor
final class LegacySensorStore: ObservableObject, SensorStoreProtocol {
    @Published var snapshots: [SensorSnapshot] = []

    // Throttling mechanism
    private var updateQueue: [String: SensorSnapshot] = [:]
    private var flushTimer: Timer?
    private let maxUpdatesPerSecond: Double = 10

    func apply(_ snap: SensorSnapshot) {
        updateQueue[snap.id] = snap
        scheduleThrottledFlush()
    }

    func remove(_ id: String) {
        updateQueue.removeValue(forKey: id)
        snapshots.removeAll { $0.id == id }
    }

    func reorder(by newOrder: [SensorSnapshot.ID]) {
        let lookup = Dictionary(uniqueKeysWithValues:
                                snapshots.map { ($0.id, $0) })

        var reordered = newOrder.compactMap { lookup[$0] }

        for snap in snapshots where !newOrder.contains(snap.id) {
            reordered.append(snap)
        }

        snapshots = reordered
    }

    private func scheduleThrottledFlush() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / maxUpdatesPerSecond, repeats: false) { _ in
            Task { @MainActor in
                self.flushUpdates()
            }
        }
    }

    private func flushUpdates() {
        guard !updateQueue.isEmpty else { return }

        var snapshotDict = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })

        for (id, newSnapshot) in updateQueue {
            snapshotDict[id] = newSnapshot
        }

        // TODO: Implement following manual or auto oder setting.
        snapshots = snapshotDict.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        updateQueue.removeAll()
    }

    func commitImmediate() {
        flushTimer?.invalidate()
        flushUpdates()
    }
}

// MARK: - iOS 17+ - Observable macro
@available(iOS 17.0, *)
@Observable
@MainActor
final class ModernSensorStore: SensorStoreProtocol {
    var snapshots: [SensorSnapshot] = []

    // Throttling mechanism
    private var updateQueue: [String: SensorSnapshot] = [:]
    private var flushTimer: Timer?
    private let maxUpdatesPerSecond: Double = 10

    func apply(_ snap: SensorSnapshot) {
        updateQueue[snap.id] = snap
        scheduleThrottledFlush()
    }

    func remove(_ id: String) {
        updateQueue.removeValue(forKey: id)
        snapshots.removeAll { $0.id == id }
    }

    func reorder(by newOrder: [SensorSnapshot.ID]) {
        let lookup = Dictionary(uniqueKeysWithValues:
                                snapshots.map { ($0.id, $0) })

        var reordered = newOrder.compactMap { lookup[$0] }

        for snap in snapshots where !newOrder.contains(snap.id) {
            reordered.append(snap)
        }

        snapshots = reordered
    }

    private func scheduleThrottledFlush() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / maxUpdatesPerSecond, repeats: false) { _ in
            Task { @MainActor in
                self.flushUpdates()
            }
        }
    }

    private func flushUpdates() {
        guard !updateQueue.isEmpty else { return }

        var snapshotDict = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })

        for (id, newSnapshot) in updateQueue {
            snapshotDict[id] = newSnapshot
        }

        // TODO: Implement following manual or auto oder setting.
        snapshots = snapshotDict.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        updateQueue.removeAll()
    }

    func commitImmediate() {
        flushTimer?.invalidate()
        flushUpdates()
    }
}
