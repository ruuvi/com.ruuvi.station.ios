import BTKit
import Foundation
import Future
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

    @discardableResult
    // swiftlint:disable function_parameter_count
    public func syncLogs(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?,
        timeouts: GATTServiceTimeouts
    ) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        if isSyncingLogs(with: uuid) {
            promise.fail(error: .isAlreadySyncingLogsWithThisTag)
        } else {
            let operation = RuuviTagReadLogsOperation(
                uuid: uuid,
                mac: mac,
                firmware: firmware,
                from: from,
                settings: settings,
                ruuviPool: ruuviPool,
                background: background,
                progress: progress,
                connectionTimeout: timeouts.connection,
                serviceTimeout: timeouts.service
            )
            operation.completionBlock = { [unowned operation] in
                if let error = operation.error {
                    promise.fail(error: error)
                } else {
                    promise.succeed(value: !operation.isCancelled)
                }
            }
            queue.addOperation(operation)
        }
        return promise.future
    }

    // swiftlint:enable function_parameter_count

    public func isSyncingLogs() -> Bool {
        queue.operations.contains(where: {
            $0 is RuuviTagReadLogsOperation &&
                !$0.isFinished && (!$0.isCancelled || $0.isExecuting)
        })
    }

    public func isSyncingLogs(with uuid: String) -> Bool {
        queue.operations.contains(where: {
            ($0 as? RuuviTagReadLogsOperation)?.uuid == uuid &&
                !$0.isFinished && (!$0.isCancelled || $0.isExecuting)
        })
    }

    public func isSyncingLogsQueued(with uuid: String) -> Bool {
        queue.operations.contains(where: { operation in
            guard let readLogsOperation = operation as? RuuviTagReadLogsOperation,
                  readLogsOperation.uuid == uuid
            else {
                return false
            }
            return !readLogsOperation.isExecuting &&
                !readLogsOperation.isFinished &&
                !readLogsOperation.isCancelled
        })
    }

    public func syncProgress(with uuid: String) -> BTServiceProgress? {
        queue.operations.compactMap { $0 as? RuuviTagReadLogsOperation }
            .first(where: { $0.uuid == uuid && !$0.isFinished && !$0.isCancelled })?
            .currentProgress
    }

    @discardableResult
    public func stopGattSync(for uuid: String) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        let operations = queue.operations.compactMap { $0 as? RuuviTagReadLogsOperation }
            .filter { $0.uuid == uuid && !$0.isFinished }
        for operation in operations {
            // Disconnect can trigger a completion callback, so mark cancellation first.
            operation.cancel()
            operation.stopSync()
        }
        promise.succeed(value: !operations.isEmpty)
        return promise.future
    }
}
