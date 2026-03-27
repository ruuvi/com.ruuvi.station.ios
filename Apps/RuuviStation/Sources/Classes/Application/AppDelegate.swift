import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import FirebaseMessaging
import UIKit
#if (DEBUG || ALPHA) && canImport(FLEX)
import FLEX
#endif
import RuuviAnalytics
import RuuviContext
import RuuviCore
import RuuviLocal
import RuuviLocalization
import RuuviMigration
import RuuviNotification
import RuuviOntology
import RuuviService
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var appStateService: AppStateService!
    var localNotificationsManager: RuuviNotificationLocal!
    var featureToggleService: FeatureToggleService!
    var cloudNotificationService: RuuviServiceCloudNotification!
    var pnManager: RuuviCorePN!
    var settings: RuuviLocalSettings!
    var orientationLock = UIInterfaceOrientationMask.allButUpsideDown

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let r = AppAssembly.shared.assembler.resolver
        settings = r.resolve(RuuviLocalSettings.self)
        setPreferrerdLanguage()

        FirebaseApp.configure()
        #if DEBUG || ALPHA
        Analytics.setAnalyticsCollectionEnabled(false)
        #endif

        Messaging.messaging().delegate = self
        pnManager = r.resolve(RuuviCorePN.self)

        featureToggleService = r.resolve(FeatureToggleService.self)
        featureToggleService.fetchFeatureToggles()

        // the order is important
        r.resolve(SQLiteContext.self)?
            .database
            .migrateIfNeeded()
        r.resolve(RuuviMigrationFactory.self)?
            .createAllOrdered()
            .forEach { $0.migrateIfNeeded() }

        appStateService = r.resolve(AppStateService.self)
        appStateService.application(application, didFinishLaunchingWithOptions: launchOptions)
        localNotificationsManager = r.resolve(RuuviNotificationLocal.self)
        let disableTitle = RuuviLocalization.LocalNotificationsManager.Disable.button
        let muteTitle = RuuviLocalization.LocalNotificationsManager.Mute.button
        localNotificationsManager.setup(
            disableTitle: disableTitle,
            muteTitle: muteTitle,
            output: self
        )

        cloudNotificationService = r.resolve(RuuviServiceCloudNotification.self)

        #if (DEBUG || ALPHA) && canImport(FLEX)
            FLEXManager.shared.registerGlobalEntry(
                withName: "Feature Toggles",
                viewControllerFutureBlock: { r.resolve(FeatureTogglesViewController.self) ?? UIViewController()
                }
            )
        #endif

        return true
    }

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(
        _: UIApplication,
        supportedInterfaceOrientationsFor _: UIWindow?
    ) -> UIInterfaceOrientationMask {
        orientationLock
    }
}

// MARK: - Push Notifications

extension AppDelegate {
    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        pnManager.pnTokenData = deviceToken

        Messaging.messaging().token { [weak self] fcmToken, _ in
            self?.register(with: fcmToken)
        }
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error.localizedDescription)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(
        _: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        register(with: fcmToken)
    }

    private func register(with fcmToken: String?) {
        guard !UIDevice.isSimulator,
              let fcmToken,
              cloudNotificationService != nil
        else {
            return
        }

        Task {
            _ = try? await cloudNotificationService.set(
                token: fcmToken,
                name: UIDevice.modelName,
                data: nil,
                language: settings.language,
                sound: settings.alertSound
            )
        }
    }

    fileprivate func setPreferrerdLanguage() {
        if let languageCode = Bundle.main.preferredLocalizations.first,
           let language = Language(rawValue: languageCode) {
            if settings.language != language {
                settings.language = language
            }
        } else {
            settings.language = .english
        }
    }
}

// MARK: - Notification tap handler

extension AppDelegate: RuuviNotificationLocalOutput {
    func notificationDidTap(for uuid: String) {
        openSelectedCard(for: uuid)
    }
}

// TODO: - SEE IF WE CAN MOVE THIS TO APP_STATE_SERVICE
extension AppDelegate {
    func widgetSensorIdentifier(from url: URL) -> String {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let sensorId = components.queryItems?.first(where: { $0.name == "sensorId" })?.value,
           !sensorId.isEmpty {
            return sensorId
        }

        if let scheme = url.scheme,
           url.host == nil,
           !url.path.isEmpty {
            return "\(scheme):\(url.path)"
        }

        return url.absoluteString.removingPercentEncoding ?? url.absoluteString
    }

    func openSelectedCard(
        for uuid: String,
        application: UIApplication? = nil
    ) {
        settings.setCardToOpenFromWidget(for: uuid)
        appStateService
            .applicationDidOpenWithWidgetDeepLink(
                application,
                macId: uuid
            )
    }
}

// MARK: Notifications badge reset
extension AppDelegate {
    func resetNotificationsBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { [weak self] error in
                guard error == nil else {
                    return
                }
                self?.settings.setNotificationsBadgeCount(value: 0)
            }
        } else {
            settings.setNotificationsBadgeCount(value: 0)
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
