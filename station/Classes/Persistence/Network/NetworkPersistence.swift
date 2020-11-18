import Foundation
extension Notification.Name {
    static let NetworkLastSyncDateDidChange = Notification.Name("NetworkPersistence.LastSyncDateDidChange")
}
protocol NetworkPersistence {
    var lastSyncDate: Date? { get set }
}
