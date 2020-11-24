import Foundation

class NetworkPersistenceImpl: NetworkPersistence {
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
