import Foundation

protocol PushNotificationsManager {
    var pnTokenData: Data? { get set }
    
    func registerForRemoteNotifications()
    func getRemoteNotificationsAuthorizationStatus(completion: @escaping (PNAuthorizationStatus) -> Void)
}

enum PNAuthorizationStatus: Int {
    case notDetermined
    case denied
    case authorized
}
