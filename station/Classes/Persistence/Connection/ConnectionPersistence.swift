import Foundation

protocol ConnectionPersistence {

    var keepConnectionUUIDs: [AnyLocalIdentifier] { get }

    func keepConnection(to luid: LocalIdentifier) -> Bool
    func setKeepConnection(_ value: Bool, for luid: LocalIdentifier)
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
