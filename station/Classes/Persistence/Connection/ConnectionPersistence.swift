import Foundation

extension Notification.Name {
    static let ConnectionPersistenceDidStartToKeepConnection = Notification.Name("ConnectionPersistenceDidStartToKeepConnection")
    static let ConnectionPersistenceDidStopToKeepConnection = Notification.Name("ConnectionPersistenceDidStopToKeepConnection")
}

enum ConnectionPersistenceDidStartToKeepConnectionKey: String {
    case uuid = "uuid"
}

enum ConnectionPersistenceDidStopToKeepConnectionKey: String {
    case uuid = "uuid"
}

protocol ConnectionPersistence {
    
    var keepConnectionUUIDs: [String] { get }
    
    func keepConnection(to uuid: String) -> Bool
    func setKeepConnection(_ value: Bool, for uuid: String)
    
    func presentConnectionNotifications(for uuid: String) -> Bool
    func setPresentConnectionNotifications(_ value: Bool, for uuid: String) 
}
