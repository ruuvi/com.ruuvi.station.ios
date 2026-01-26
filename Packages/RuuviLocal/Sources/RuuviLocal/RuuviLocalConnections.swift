import Foundation
import RuuviOntology

public protocol RuuviLocalConnections: Sendable {
    func getKeepConnectionUUIDs() async -> [AnyLocalIdentifier]

    func keepConnection(to luid: LocalIdentifier) async -> Bool
    func setKeepConnection(_ value: Bool, for luid: LocalIdentifier) async
    func unpairAllConnection() async
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
