import Foundation
import Future

protocol GATTService {
    
    func isSyncingLogs(with uuid: String) -> Bool
    
    @discardableResult
    func syncLogs(with uuid: String) -> Future<Bool,RUError>
}
