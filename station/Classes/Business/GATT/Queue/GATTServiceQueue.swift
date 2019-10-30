import Foundation
import BTKit

class GATTServiceQueue: GATTService {
    var connectionPersistence: ConnectionPersistence!
    var ruuviTagPersistence: RuuviTagPersistence!
    var background: BTBackground!
    
    lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
    
    func syncLogs(with uuid: String) {
        let operation = RuuviTagReadLogsOperation(uuid: uuid, ruuviTagPersistence: ruuviTagPersistence, connectionPersistence: connectionPersistence, background: background)
        queue.addOperation(operation)
    }
    
    func isSyncingLogs(with uuid: String) -> Bool {
        return queue.operations.contains(where: { ($0 as? RuuviTagReadLogsOperation)?.uuid == uuid })
    }
}
