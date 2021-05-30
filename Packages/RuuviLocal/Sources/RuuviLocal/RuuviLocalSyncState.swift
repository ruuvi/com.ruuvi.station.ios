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

extension Notification.Name {
    public static let NetworkLastSyncDateDidChange = Notification.Name("NetworkPersistence.LastSyncDateDidChange")
    public static let NetworkSyncDidChangeStatus = Notification.Name("NetworkPersistence.DidChangeStatus")
    public static let NetworkSyncDidChangeCommonStatus = Notification.Name("NetworkPersistence.DidChangeCommonStatus")
}

public protocol RuuviLocalSyncState {
    var lastSyncDate: Date? { get set }
    var syncStatus: NetworkSyncStatus { get set }
    func setSyncStatus(_ status: NetworkSyncStatus, for macId: MACIdentifier)
    func getSyncStatus(for macId: MACIdentifier) -> NetworkSyncStatus
}
