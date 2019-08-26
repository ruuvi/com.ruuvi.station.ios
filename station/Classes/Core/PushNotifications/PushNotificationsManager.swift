import Foundation

protocol PushNotificationsManager {
    func registerForRemoteNotifications()
    func getRemoteNotificationsAuthorizationStatus(completion: @escaping (PNAuthorizationStatus) -> Void)
}

enum PNAuthorizationStatus: Int {
    case notDetermined
    case denied
    case authorized
}
