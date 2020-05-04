import Foundation

protocol ConnectionPersistence {

    var keepConnectionUUIDs: [String] { get }

    func keepConnection(to uuid: String) -> Bool
    func setKeepConnection(_ value: Bool, for uuid: String)
}

extension Notification.Name {
    static let ConnectionPersistenceDidStartToKeepConnection =
        Notification.Name("ConnectionPersistenceDidStartToKeepConnection")
    static let ConnectionPersistenceDidStopToKeepConnection =
        Notification.Name("ConnectionPersistenceDidStopToKeepConnection")
}

enum CPDidStartToKeepConnectionKey: String {
    case uuid
}

enum CPDidStopToKeepConnectionKey: String {
    case uuid
}
