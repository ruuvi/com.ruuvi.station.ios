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
        default:
            break
        }
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
}
