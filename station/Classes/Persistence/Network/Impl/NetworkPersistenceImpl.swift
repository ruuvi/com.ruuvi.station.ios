import Foundation

enum NetworkSyncStatus: Int {
    case none = 0
    case syncing
    case complete
    case onError
}

enum NetworkSyncStatusKey: String {
    case mac
    case status
}

class NetworkPersistenceImpl: NetworkPersistence {

    private let networkSyncStatusPrefix = "NetworkPersistence.syncState."
    private var syncingEnqueue: [AnyMACIdentifier] = []

    func setSyncStatus(_ status: NetworkSyncStatus, for macId: MACIdentifier) {
        UserDefaults.standard.set(status.rawValue, forKey: networkSyncStatusPrefix + macId.mac)
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(name: .NetworkSyncDidChangeStatus, object: nil, userInfo: [
                    NetworkSyncStatusKey.mac: macId,
                    NetworkSyncStatusKey.status: status
                ])
        }
        switch status {
        case .complete, .onError:
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1),
                                          execute: { [weak self] in
                self?.setSyncStatus(.none, for: macId)
            })
        case .syncing:
            if syncingEnqueue.isEmpty {
                syncStatus = .syncing
            }
            syncingEnqueue.append(macId.any)
        case .none:
            syncingEnqueue.removeAll(where: {$0 == macId.any})
            if syncingEnqueue.isEmpty {
                syncStatus = .none
            }
        }
        debugPrint(syncingEnqueue)
    }

    func getSyncStatus(for macId: MACIdentifier) -> NetworkSyncStatus {
        let value = UserDefaults.standard.integer(forKey: networkSyncStatusPrefix + macId.mac)
        return NetworkSyncStatus(rawValue: value) ?? .none
    }

    @UserDefault("NetworkPersistence.lastSyncDate", defaultValue: nil)
    var lastSyncDate: Date? {
        didSet {
            NotificationCenter
                .default
                .post(name: .NetworkLastSyncDateDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    @UserDefault("NetworkPersistence.syncStatus", defaultValue: 0)
    private var syncStatusInt: Int

    var syncStatus: NetworkSyncStatus {
        get {
            return NetworkSyncStatus(rawValue: syncStatusInt) ?? NetworkSyncStatus.none
        }
        set {
            syncStatusInt = newValue.rawValue
            NotificationCenter
                .default
                .post(name: .NetworkSyncDidChangeCommonStatus, object: self, userInfo: [
                    NetworkSyncStatusKey.status: newValue
                ])
        }
    }
}
