import BTKit
import Foundation
import RuuviOntology
import RuuviPool

public final class GATTServiceQueue: GATTService {
    typealias ReadLogsOperationFactory = (
        String,
        String?,
        Int,
        Date,
        SensorSettings?,
        ((BTServiceProgress) -> Void)?,
        TimeInterval?,
        TimeInterval?
    ) -> Operation & RuuviTagReadLogsOperable

    private let operationFactory: ReadLogsOperationFactory

    public init(
        ruuviPool: RuuviPool,
        background: BTBackground
    ) {
        operationFactory = { uuid, mac, firmware, from, settings, progress, connectionTimeout, serviceTimeout in
            RuuviTagReadLogsOperation(
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
        }
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
    }

    init(
        queue: OperationQueue,
        operationFactory: @escaping ReadLogsOperationFactory
    ) {
        self.queue = queue
        self.operationFactory = operationFactory
    }

    var queue: OperationQueue

    @discardableResult
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
            let operation = operationFactory(
                uuid,
                mac,
                firmware,
                from,
                settings,
                progress,
                connectionTimeout,
                serviceTimeout
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
        queue.operations.contains(where: { ($0 as? RuuviTagReadLogsOperable)?.uuid == uuid })
    }

    public func isSyncingLogsQueued(with uuid: String) -> Bool {
        queue.operations.contains(where: { operation in
            guard let readLogsOperation = operation as? RuuviTagReadLogsOperable,
                  readLogsOperation.uuid == uuid
            else {
                return false
            }
            return !readLogsOperation.isExecuting &&
                !readLogsOperation.isFinished &&
                !readLogsOperation.isCancelled
        })
    }

    @discardableResult
    public func stopGattSync(for uuid: String) async throws -> Bool {
        if let operation = queue.operations
            .first(where: { ($0 as? RuuviTagReadLogsOperable)?.uuid == uuid }) {
            if let queueOperation = operation as? RuuviTagReadLogsOperable {
                queueOperation.stopSync()
            }
            operation.cancel()
            return operation.isCancelled
        } else {
            return false
        }
    }
}
