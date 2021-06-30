import Foundation
import BTKit
import Future
import RuuviOntology
import RuuviPool
import RuuviService

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
        settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?,
        connectionTimeout: TimeInterval?,
        serviceTimeout: TimeInterval?
    ) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        if isSyncingLogs(with: uuid) {
            promise.fail(error: .isAlreadySyncingLogsWithThisTag)
        } else {
            let operation = RuuviTagReadLogsOperation(
                uuid: uuid,
                mac: mac,
                settings: settings,
                ruuviPool: ruuviPool,
                background: background,
                progress: progress,
                connectionTimeout: connectionTimeout,
                serviceTimeout: serviceTimeout
            )
            operation.completionBlock = { [unowned operation] in
                if let error = operation.error {
                    promise.fail(error: error)
                } else {
                    promise.succeed(value: true)
                }
            }
            queue.addOperation(operation)
        }
        return promise.future
    }
    // swiftlint:enable function_parameter_count

    public func isSyncingLogs(with uuid: String) -> Bool {
        return queue.operations.contains(where: { ($0 as? RuuviTagReadLogsOperation)?.uuid == uuid })
    }
}
