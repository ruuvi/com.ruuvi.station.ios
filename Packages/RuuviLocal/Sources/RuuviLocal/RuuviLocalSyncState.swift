import Foundation
import RuuviOntology

public enum NetworkSyncStatus: Int {
    case none = 0
    case syncing
    case complete
    case onError
}

public enum NetworkSyncStatusKey: String {
    case mac
    case status
}

public extension Notification.Name {
    static let NetworkSyncDidChangeStatus =
        Notification.Name("NetworkPersistence.DidChangeStatus")
    static let NetworkSyncDidComplete =
        Notification.Name("NetworkPersistence.NetworkSyncDidComplete")
    static let NetworkHistorySyncDidCompleteForSensor =
        Notification.Name("NetworkPersistence.NetworkHistorySyncDidCompleteForSensor")
    static let NetworkSyncDidChangeCommonStatus =
        Notification.Name("NetworkPersistence.DidChangeCommonStatus")
    static let NetworkSyncDidFailForAuthorization =
        Notification.Name("NetworkPersistence.NetworkSyncDidFailForAuthorization")
}

public protocol RuuviLocalSyncState {
    func setSyncStatus(_ status: NetworkSyncStatus, for macId: MACIdentifier)
    func getSyncStatus(for macId: MACIdentifier) -> NetworkSyncStatus
    func setSyncDate(_ date: Date?, for macId: MACIdentifier?)
    func getSyncDate(for macId: MACIdentifier?) -> Date?
    func setGattSyncDate(_ date: Date?, for macId: MACIdentifier?)
    func getGattSyncDate(for macId: MACIdentifier?) -> Date?
    func setSyncDate(_ date: Date?)
    func getSyncDate() -> Date?
    func setDownloadFullHistory(for macId: MACIdentifier?, downloadFull: Bool?)
    func downloadFullHistory(for macId: MACIdentifier?) -> Bool?
}
