import UIKit
import RuuviCore
import UserNotifications

public final class RuuviCorePNImpl: NSObject, RuuviCorePN {
    override public init() {
        super.init()
    }

    public var pnTokenData: Data? {
        get {
            return UserDefaults.standard.data(forKey: pnTokenDataUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: pnTokenDataUDKey)
        }
    }

    public func getRemoteNotificationsAuthorizationStatus(completion: @escaping (PNAuthorizationStatus) -> Void) {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                DispatchQueue.main.async {
                    switch settings.authorizationStatus {
                    case .authorized:
                        completion(.authorized)
                    case .provisional:
                        completion(.authorized)
                    case .denied:
                        completion(.denied)
                    case .notDetermined:
                        completion(.notDetermined)
                    case .ephemeral:
                        completion(.notDetermined)
                    @unknown default:
                        completion(.denied)
                    }
                }
            }
        } else {
            if UIApplication.shared.isRegisteredForRemoteNotifications {
                completion(.authorized)
            } else if didAskForRemoteNotificationPermission {
                completion(.denied)
            } else {
                completion(.notDetermined)
            }
        }
    }

    public func registerForRemoteNotifications() {
        if #available(iOS 10.0, *) {
            let center  = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.sound, .alert, .badge]) { (_, error) in
                if error == nil {
                    DispatchQueue.main.async {
                        self.didAskForRemoteNotificationPermission = true
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        } else {
            let settings = UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil)
            UIApplication
                .shared
                .registerUserNotificationSettings(settings)
            didAskForRemoteNotificationPermission = true
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private let pnTokenDataUDKey = "PushNotificationsManagerImpl.pnTokenDataUDKey"
    private let didAskForRemoteNotificationPermissionUDKey =
    "PushNotificationsManagerImpl.didAskForRemoteNotificationPermissionUDKey"
    private var didAskForRemoteNotificationPermission: Bool {
        get {
            return UserDefaults.standard.bool(forKey: didAskForRemoteNotificationPermissionUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: didAskForRemoteNotificationPermissionUDKey)
        }
    }
}
