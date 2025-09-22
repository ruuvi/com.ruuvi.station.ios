import BTKit
import Foundation
import RuuviOntology
import RuuviPool

public final class GATTServiceQueue: GATTService {
    private let ruuviPool: RuuviPool
    private let background: BTBackground

    public init(
        ruuviPool: RuuviPool,
        background: BTBackground
    ) {
        self.ruuviPool = ruuviPool
        self.background = background
    }

    lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    // swiftlint:disable function_parameter_count
    public func syncLogs(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?,
        connectionTimeout: TimeInterval?,
        serviceTimeout: TimeInterval?
    ) async throws -> Bool {
        if isSyncingLogs(with: uuid) {
            throw RuuviServiceError.isAlreadySyncingLogsWithThisTag
        }
        return try await withCheckedThrowingContinuation { continuation in
            let operation = RuuviTagReadLogsOperation(
                uuid: uuid,
                mac: mac,
                firmware: firmware,
                from: from,
                settings: settings,
                ruuviPool: ruuviPool,
                background: background,
                progress: progress,
                connectionTimeout: connectionTimeout,
                serviceTimeout: serviceTimeout
            )
            operation.completionBlock = { [unowned operation] in
                if let error = operation.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: true)
                }
            }
            queue.addOperation(operation)
        }
    }
    // swiftlint:enable function_parameter_count

    public func isSyncingLogs(with uuid: String) -> Bool {
        queue.operations.contains(where: { ($0 as? RuuviTagReadLogsOperation)?.uuid == uuid })
    }

    public func stopGattSync(for uuid: String) async throws -> Bool {
        guard isSyncingLogs(with: uuid) else { return false }
        guard let operation = queue.operations.first(where: { ($0 as? RuuviTagReadLogsOperation)?.uuid == uuid }) else {
            return false
        }
        if let queueOperation = operation as? RuuviTagReadLogsOperation {
            queueOperation.stopSync()
        }
        operation.cancel()
        return operation.isCancelled
    }
}
