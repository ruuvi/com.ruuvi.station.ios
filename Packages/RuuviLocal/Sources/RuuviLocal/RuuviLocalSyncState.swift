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
    public static let NetworkSyncDidChangeStatus = Notification.Name("NetworkPersistence.DidChangeStatus")
    public static let NetworkSyncDidChangeCommonStatus = Notification.Name("NetworkPersistence.DidChangeCommonStatus")
}

public protocol RuuviLocalSyncState {
    func setSyncStatus(_ status: NetworkSyncStatus, for macId: MACIdentifier)
    func getSyncStatus(for macId: MACIdentifier) -> NetworkSyncStatus
    func setSyncDate(_ date: Date?, for macId: MACIdentifier?)
    func getSyncDate(for macId: MACIdentifier?) -> Date?
    func setGattSyncDate(_ date: Date?, for macId: MACIdentifier?)
    func getGattSyncDate(for macId: MACIdentifier?) -> Date?
}
