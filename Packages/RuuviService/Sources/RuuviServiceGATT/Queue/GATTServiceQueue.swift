#if SWIFT_PACKAGE
    import RuuviService
#endif
import BTKit
import Foundation
import RuuviOntology
import RuuviPool

public final class GATTServiceQueue: GATTService {
    private let ruuviPool: RuuviPool
    private let background: BTBackground
    private let lock = NSLock()
    private var operations = [String: RuuviTagReadLogsOperation]()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    public init(ruuviPool: RuuviPool, background: BTBackground) {
        self.ruuviPool = ruuviPool
        self.background = background
    }

    public func syncLogs(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?,
        timeouts: GATTServiceTimeouts
    ) async throws(RuuviServiceError) -> Bool {
        let operation = RuuviTagReadLogsOperation(
            uuid: uuid, mac: mac, firmware: firmware, from: from, settings: settings,
            ruuviPool: ruuviPool, background: background, progress: progress,
            connectionTimeout: timeouts.connection, serviceTimeout: timeouts.service
        )
        let registered = lock.withLock {
            guard operations[uuid] == nil else { return false }
            operations[uuid] = operation
            return true
        }
        guard registered else { throw .isAlreadySyncingLogsWithThisTag }
        defer { lock.withLock { _ = operations.removeValue(forKey: uuid) } }
        let result: Result<Bool, RuuviServiceError> = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                operation.completionBlock = { [weak operation] in
                    guard let operation else {
                        continuation.resume(returning: .success(false))
                        return
                    }
                    if let error = operation.error {
                        continuation.resume(returning: .failure(error))
                    } else {
                        continuation.resume(returning: .success(!operation.isCancelled))
                    }
                }
                if Task.isCancelled { operation.cancel() }
                queue.addOperation(operation)
            }
        } onCancel: {
            operation.cancel()
            operation.stopSync()
        }
        // Cancellation cannot expose completion before an already-started write has drained.
        await operation.waitForPersistence()
        return try result.get()
    }

    public func isSyncingLogs() -> Bool { lock.withLock { !operations.isEmpty } }
    public func isSyncingLogs(with uuid: String) -> Bool { lock.withLock { operations[uuid] != nil } }
    public func isSyncingLogsQueued(with uuid: String) -> Bool {
        lock.withLock {
            guard let operation = operations[uuid] else { return false }
            return !operation.isExecuting && !operation.isFinished && !operation.isCancelled
        }
    }
    public func syncProgress(with uuid: String) -> BTServiceProgress? {
        lock.withLock { operations[uuid]?.currentProgress }
    }

    public func stopGattSync(for uuid: String) async throws(RuuviServiceError) -> Bool {
        guard let operation = lock.withLock({ operations[uuid] }) else { return false }
        operation.cancel()
        operation.stopSync()
        await operation.waitForPersistence()
        return true
    }
}
