#if SWIFT_PACKAGE
    import RuuviCore
#endif
import UIKit
import UserNotifications

struct NotificationAccess {
    var status: (@escaping (UNAuthorizationStatus) -> Void) -> Void
    var request: (UNAuthorizationOptions, @escaping (Bool, Error?) -> Void) -> Void
    var register: @MainActor () -> Void

    static var system: NotificationAccess {
        NotificationAccess(
            status: { callback in
                UNUserNotificationCenter.current().getNotificationSettings { callback($0.authorizationStatus) }
            },
            request: { UNUserNotificationCenter.current().requestAuthorization(options: $0, completionHandler: $1) },
            register: { UIApplication.shared.registerForRemoteNotifications() })
    }
}

public final class RuuviCorePNImpl: NSObject, RuuviCorePN {
    private let defaults: UserDefaults
    private let access: NotificationAccess

    override public convenience init() {
        self.init(defaults: .standard, access: .system)
    }

    init(defaults: UserDefaults, access: NotificationAccess) {
        self.defaults = defaults
        self.access = access
        super.init()
    }

    public var pnTokenData: Data? {
        get {
            defaults.data(forKey: pnTokenDataUDKey)
        }
        set {
            defaults.set(newValue, forKey: pnTokenDataUDKey)
        }
    }

    public var fcmToken: String? {
        get {
            defaults.string(forKey: pnFCMTokenUDKey)
        }
        set {
            defaults.set(newValue, forKey: pnFCMTokenUDKey)
        }
    }

    public var fcmTokenId: Int? {
        get {
            defaults.object(forKey: pnFCMTokenIdUDKey) as? Int
        }
        set {
            defaults.set(newValue, forKey: pnFCMTokenIdUDKey)
        }
    }

    public var fcmTokenLastRefreshed: Date? {
        get {
            defaults.object(forKey: pnFCMTokenLastRefreshUDKey) as? Date
        }
        set {
            defaults.set(newValue, forKey: pnFCMTokenLastRefreshUDKey)
        }
    }

    public func getRemoteNotificationsAuthorizationStatus(completion: @escaping (PNAuthorizationStatus) -> Void) {
        access.status { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .provisional, .ephemeral:
                    completion(.authorized)
                case .denied:
                    completion(.denied)
                case .notDetermined:
                    completion(.notDetermined)
                @unknown default:
                    completion(.denied)
                }
            }
        }
    }

    public func registerForRemoteNotifications() {
        let register = access.register
        access.request([.sound, .alert, .badge]) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async { register() }
        }
    }

    private let pnTokenDataUDKey = "PushNotificationsManagerImpl.pnTokenDataUDKey"
    private let pnFCMTokenUDKey = "PushNotificationsManagerImpl.pnFCMTokenUDKey"
    private let pnFCMTokenIdUDKey = "PushNotificationsManagerImpl.pnFCMTokenIdUDKey"
    private let pnFCMTokenLastRefreshUDKey = "PushNotificationsManagerImpl.pnFCMTokenLastRefreshUDKey"
}
