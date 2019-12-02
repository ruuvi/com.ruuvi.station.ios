import Foundation

protocol ConnectionPersistence {

    var keepConnectionUUIDs: [String] { get }
    var readRSSIUUIDs: [String] { get }

    func keepConnection(to uuid: String) -> Bool
    func setKeepConnection(_ value: Bool, for uuid: String)

    func presentConnectionNotifications(for uuid: String) -> Bool
    func setPresentConnectionNotifications(_ value: Bool, for uuid: String)

    func saveHeartbeats(uuid: String) -> Bool
    func setSaveHeartbeats(_ value: Bool, uuid: String)

    func saveHeartbeatsInterval(uuid: String) -> Int
    func setSaveHeartbeatsInterval(_ value: Int, uuid: String)

    func readRSSI(uuid: String) -> Bool
    func setReadRSSI(_ value: Bool, uuid: String)

    func readRSSIInterval(uuid: String) -> Int
    func setReadRSSIInterval(_ value: Int, uuid: String)

    func logSyncDate(uuid: String) -> Date?
    func setLogSyncDate(_ value: Date?, uuid: String)
}

extension Notification.Name {
    static let ConnectionPersistenceDidStartToKeepConnection =
        Notification.Name("ConnectionPersistenceDidStartToKeepConnection")
    static let ConnectionPersistenceDidStopToKeepConnection =
        Notification.Name("ConnectionPersistenceDidStopToKeepConnection")
    static let ConnectionPersistenceDidStartReadingRSSI =
        Notification.Name("ConnectionPersistenceDidStartReadingRSSI")
    static let ConnectionPersistenceDidStopReadingRSSI =
        Notification.Name("ConnectionPersistenceDidStopReadingRSSI")
    static let ConnectionPersistenceDidChangeReadRSSIInterval =
        Notification.Name("ConnectionPersistenceDidChangeReadRSSIInterval")
}

enum CPDidStartToKeepConnectionKey: String {
    case uuid
    case readRSSI // Bool
}

enum CPDidStopToKeepConnectionKey: String {
    case uuid
    case readRSSI // Bool
}

enum CPDidStartReadingRSSIKey: String {
    case uuid
}

enum CPDidStopReadingRSSIKey: String {
    case uuid
}

enum CPDidChangeReadRSSIIntervalKey: String {
    case uuid
    case interval // Int (seconds)
}
