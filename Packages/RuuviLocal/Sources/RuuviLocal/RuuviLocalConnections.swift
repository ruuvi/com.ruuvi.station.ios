import Foundation
import RuuviOntology

public protocol RuuviLocalConnections {
    var keepConnectionUUIDs: [AnyLocalIdentifier] { get }

    func keepConnection(to luid: LocalIdentifier) -> Bool
    func setKeepConnection(_ value: Bool, for luid: LocalIdentifier)
    func unpairAllConnection()
}

public extension Notification.Name {
    static let ConnectionPersistenceDidStartToKeepConnection =
        Notification.Name("ConnectionPersistenceDidStartToKeepConnection")
    static let ConnectionPersistenceDidStopToKeepConnection =
        Notification.Name("ConnectionPersistenceDidStopToKeepConnection")
}

public enum CPDidStartToKeepConnectionKey: String {
    case uuid
}

public enum CPDidStopToKeepConnectionKey: String {
    case uuid
}
