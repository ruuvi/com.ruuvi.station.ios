#if SWIFT_PACKAGE
    import RuuviOntology
    import RuuviStorage
    import RuuviCloud
    import RuuviPool
    import RuuviLocal
    import RuuviRepository
    import RuuviCore
#endif
import Foundation

/// Owns finite background operations started by synchronous application entry points.
/// The lock protects the registry; each operation owns its own isolation and error handling.
public final class RuuviTaskStore: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks = [UUID: Task<Void, Never>]()
    private var serialTails = [String: UUID]()

    public init() {}

    public func run(_ operation: @escaping @Sendable () async -> Void) {
        let id = UUID()
        lock.withLock {
            tasks[id] = Task { [weak self] in
                await operation()
                self?.remove(id)
            }
        }
    }

    /// Preserves submission order for writes to one remote resource without blocking other resources.
    public func run(seriallyFor key: String, _ operation: @escaping @Sendable () async -> Void) {
        let id = UUID()
        lock.withLock {
            let previous = serialTails[key].flatMap { tasks[$0] }
            serialTails[key] = id
            tasks[id] = Task { [weak self] in
                await previous?.value
                if !Task.isCancelled { await operation() }
                self?.remove(id, key: key)
            }
        }
    }

    public func cancelAll() {
        let active = lock.withLock {
            let active = Array(tasks.values)
            tasks.removeAll()
            serialTails.removeAll()
            return active
        }
        for task in active { task.cancel() }
    }

    private func remove(_ id: UUID, key: String? = nil) {
        lock.withLock {
            tasks.removeValue(forKey: id)
            if let key, serialTails[key] == id { serialTails.removeValue(forKey: key) }
        }
    }
    deinit { cancelAll() }
}

/// Executes independent operations with a fixed upper bound and returns values in input order.
/// All started work is joined before success or failure is returned.
public func ruuviConcurrentMap<Input, Output, Failure: Error>(
    _ inputs: [Input],
    limit: Int = 3,
    operation: @escaping (Input) async throws(Failure) -> Output
) async throws(Failure) -> [Output] {
    let results = await withTaskGroup(of: (Int, Result<Output, Failure>).self) { group in
        var next = 0
        var results = [(Int, Result<Output, Failure>)]()
        func enqueue(_ index: Int) {
            group.addTask {
                do throws(Failure) { return (index, .success(try await operation(inputs[index]))) } catch {
                    return (index, .failure(error))
                }
            }
        }
        while next < min(max(1, limit), inputs.count) { enqueue(next); next += 1 }
        while let result = await group.next() {
            results.append(result)
            if next < inputs.count { enqueue(next); next += 1 }
        }
        return results.sorted { $0.0 < $1.0 }
    }
    var values = [Output]()
    for (_, result) in results { values.append(try result.get()) }
    return values
}
