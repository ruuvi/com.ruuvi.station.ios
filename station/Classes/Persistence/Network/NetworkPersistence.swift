import Foundation

extension Notification.Name {
    static let NetworkLastSyncDateDidChange = Notification.Name("NetworkPersistence.LastSyncDateDidChange")
    static let NetworkSyncDidChangeStatus = Notification.Name("NetworkPersistence.DidChangeStatus")
    static let NetworkSyncDidChangeCommonStatus = Notification.Name("NetworkPersistence.DidChangeCommonStatus")
}

protocol NetworkPersistence {
    var lastSyncDate: Date? { get set }
    var syncStatus: NetworkSyncStatus { get set }
    func setSyncStatus(_ status: NetworkSyncStatus, for macId: MACIdentifier)
    func getSyncStatus(for macId: MACIdentifier) -> NetworkSyncStatus
}
