import Foundation

// Serialize sensor invalidation with write submission, including asynchronous continuations.
final class AdvertisementPersistenceGate {
    private let lock = NSRecursiveLock()
    private var generations: [String: UUID] = [:]

    func syncSensors(_ sensorIDs: Set<String>, updateCache: () -> Void = {}) {
        lock.lock()
        defer { lock.unlock() }
        generations = sensorIDs.reduce(into: [:]) { result, id in
            result[id] = generations[id] ?? UUID()
        }
        updateCache()
    }

    func generation(for sensorID: String) -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        return generations[sensorID]
    }

    func invalidate(sensorID: String) {
        lock.lock()
        defer { lock.unlock() }
        guard generations[sensorID] != nil else { return }
        generations[sensorID] = UUID()
    }

    func performIfValid(sensorID: String, generation: UUID, _ write: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard generations[sensorID] == generation else { return }
        write()
    }
}
