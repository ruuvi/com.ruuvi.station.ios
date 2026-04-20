import UIKit
import UserNotifications

protocol UserNotificationCentering: AnyObject {
    func getAuthorizationStatus(
        completionHandler: @escaping @Sendable (UNAuthorizationStatus) -> Void
    )
    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, Error?) -> Void
    )
}

protocol RemoteNotificationApplicationing: AnyObject {
    var isRegisteredForRemoteNotifications: Bool { get }
    func registerForRemoteNotifications()
    func registerUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings)
}

extension UNUserNotificationCenter: UserNotificationCentering {
    func getAuthorizationStatus(
        completionHandler: @escaping @Sendable (UNAuthorizationStatus) -> Void
    ) {
        getNotificationSettings { settings in
            completionHandler(settings.authorizationStatus)
        }
    }
}
extension UIApplication: RemoteNotificationApplicationing {}

public final class RuuviCorePNImpl: NSObject, RuuviCorePN {
    private let userDefaults: UserDefaults
    private let notificationCenterProvider: () -> UserNotificationCentering
    private let applicationProvider: () -> RemoteNotificationApplicationing

    override public init() {
        userDefaults = .standard
        notificationCenterProvider = { UNUserNotificationCenter.current() }
        applicationProvider = { UIApplication.shared }
        super.init()
    }

    init(
        userDefaults: UserDefaults,
        notificationCenter: UserNotificationCentering,
        application: RemoteNotificationApplicationing
    ) {
        self.userDefaults = userDefaults
        notificationCenterProvider = { notificationCenter }
        applicationProvider = { application }
        super.init()
    }

    private var notificationCenter: UserNotificationCentering {
        notificationCenterProvider()
    }

    private var application: RemoteNotificationApplicationing {
        applicationProvider()
    }

    public var pnTokenData: Data? {
        get {
            userDefaults.data(forKey: pnTokenDataUDKey)
        }
        set {
            userDefaults.set(newValue, forKey: pnTokenDataUDKey)
        }
    }

    public var fcmToken: String? {
        get {
            userDefaults.string(forKey: pnFCMTokenUDKey)
        }
        set {
            userDefaults.set(newValue, forKey: pnFCMTokenUDKey)
        }
    }

    public var fcmTokenId: Int? {
        get {
            guard userDefaults.object(forKey: pnFCMTokenIdUDKey) != nil else {
                return nil
            }
            return userDefaults.integer(forKey: pnFCMTokenIdUDKey)
        }
        set {
            userDefaults.set(newValue, forKey: pnFCMTokenIdUDKey)
        }
    }

    public var fcmTokenLastRefreshed: Date? {
        get {
            userDefaults
                .object(forKey: pnFCMTokenLastRefreshUDKey) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: pnFCMTokenLastRefreshUDKey)
        }
    }

    static func authorizationStatus(
        from status: UNAuthorizationStatus
    ) -> PNAuthorizationStatus {
        switch status {
        case .authorized:
            return .authorized
        case .provisional:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .ephemeral:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    static func legacyAuthorizationStatus(
        isRegisteredForRemoteNotifications: Bool,
        didAskForRemoteNotificationPermission: Bool
    ) -> PNAuthorizationStatus {
        if isRegisteredForRemoteNotifications {
            return .authorized
        } else if didAskForRemoteNotificationPermission {
            return .denied
        } else {
            return .notDetermined
        }
    }

    public func getRemoteNotificationsAuthorizationStatus(completion: @escaping (PNAuthorizationStatus) -> Void) {
        notificationCenter.getAuthorizationStatus { status in
            DispatchQueue.main.async {
                completion(Self.authorizationStatus(from: status))
            }
        }
    }

    public func registerForRemoteNotifications() {
        notificationCenter.requestAuthorization(options: [.sound, .alert, .badge]) { _, error in
            if error == nil {
                DispatchQueue.main.async {
                    self.didAskForRemoteNotificationPermission = true
                    self.application.registerForRemoteNotifications()
                }
            }
        }
    }

    func legacyRemoteNotificationsAuthorizationStatus() -> PNAuthorizationStatus {
        Self.legacyAuthorizationStatus(
            isRegisteredForRemoteNotifications: application.isRegisteredForRemoteNotifications,
            didAskForRemoteNotificationPermission: didAskForRemoteNotificationPermission
        )
    }

    func registerForRemoteNotificationsLegacy() {
        let settings = UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil)
        application.registerUserNotificationSettings(settings)
        didAskForRemoteNotificationPermission = true
        application.registerForRemoteNotifications()
    }

    private let pnTokenDataUDKey = "PushNotificationsManagerImpl.pnTokenDataUDKey"
    private let pnFCMTokenUDKey = "PushNotificationsManagerImpl.pnFCMTokenUDKey"
    private let pnFCMTokenIdUDKey = "PushNotificationsManagerImpl.pnFCMTokenIdUDKey"
    private let pnFCMTokenLastRefreshUDKey = "PushNotificationsManagerImpl.pnFCMTokenLastRefreshUDKey"
    private let didAskForRemoteNotificationPermissionUDKey =
        "PushNotificationsManagerImpl.didAskForRemoteNotificationPermissionUDKey"
    private var didAskForRemoteNotificationPermission: Bool {
        get {
            userDefaults.bool(forKey: didAskForRemoteNotificationPermissionUDKey)
        }
        set {
            userDefaults.set(newValue, forKey: didAskForRemoteNotificationPermissionUDKey)
        }
    }
}
