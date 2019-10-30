import Foundation

protocol GATTService {
    
    func isSyncingLogs(with uuid: String) -> Bool
    func syncLogs(with uuid: String)
}
