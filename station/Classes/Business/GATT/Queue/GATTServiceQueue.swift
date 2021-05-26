import Foundation
import BTKit
import Future
import RuuviOntology

class GATTServiceQueue: GATTService {
    var ruuviTagTank: RuuviTagTank!
    var background: BTBackground!

    lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    // swiftlint:disable function_parameter_count
    @discardableResult
    func syncLogs(uuid: String,
                  mac: String?,
                  settings: SensorSettings?,
                  progress: ((BTServiceProgress) -> Void)?,
                  connectionTimeout: TimeInterval?,
                  serviceTimeout: TimeInterval?) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if isSyncingLogs(with: uuid) {
            promise.fail(error: .expected(.isAlreadySyncingLogsWithThisTag))
        } else {
            let operation = RuuviTagReadLogsOperation(uuid: uuid,
                                                      mac: mac,
                                                      settings: settings,
                                                      ruuviTagTank: ruuviTagTank,
                                                      background: background,
                                                      progress: progress,
                                                      connectionTimeout: connectionTimeout,
                                                      serviceTimeout: serviceTimeout)
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

    func isSyncingLogs(with uuid: String) -> Bool {
        return queue.operations.contains(where: { ($0 as? RuuviTagReadLogsOperation)?.uuid == uuid })
    }
}
