import Foundation

extension Notification.Name {
    static let NetworkLastSyncDateDidChange = Notification.Name("NetworkPersistence.LastSyncDateDidChange")
    static let NetworkSyncDidChangeStatus = Notification.Name("NetworkPersistence.DidChangeStatus")
}

protocol NetworkPersistence {
    var lastSyncDate: Date? { get set }
    func setSyncStatus(_ status: NetworkSyncStatus, for macId: MACIdentifier)
    func getSyncStatus(for macId: MACIdentifier) -> NetworkSyncStatus
}
