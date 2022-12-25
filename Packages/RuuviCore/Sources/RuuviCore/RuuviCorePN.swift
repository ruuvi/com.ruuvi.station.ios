import Foundation

public protocol RuuviCorePN {
    var pnTokenData: Data? { get set }
    var fcmToken: String? { get set }
    var fcmTokenId: Int? { get set }
    var fcmTokenLastRefreshed: Date? { get set }

    func registerForRemoteNotifications()
    func getRemoteNotificationsAuthorizationStatus(
        completion: @escaping (PNAuthorizationStatus) -> Void
    )
}

public enum PNAuthorizationStatus: Int {
    case notDetermined
    case denied
    case authorized
}
