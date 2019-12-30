import Foundation
import BTKit
import Future

class GATTServiceQueue: GATTService {
    var connectionPersistence: ConnectionPersistence!
    var ruuviTagPersistence: RuuviTagPersistence!
    var background: BTBackground!
    
    lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
    
    @discardableResult
    func syncLogs(with uuid: String, progress: ((BTServiceProgress) -> Void)? = nil, connectionTimeout: TimeInterval? = nil, serviceTimeout: TimeInterval? = nil) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        if isSyncingLogs(with: uuid) {
            promise.fail(error: .expected(.isAlreadySyncingLogsWithThisTag))
        } else {
            let operation = RuuviTagReadLogsOperation(uuid: uuid, ruuviTagPersistence: ruuviTagPersistence, connectionPersistence: connectionPersistence, background: background, progress: progress, connectionTimeout: connectionTimeout, serviceTimeout: serviceTimeout)
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
    
    func isSyncingLogs(with uuid: String) -> Bool {
        return queue.operations.contains(where: { ($0 as? RuuviTagReadLogsOperation)?.uuid == uuid })
    }
}
