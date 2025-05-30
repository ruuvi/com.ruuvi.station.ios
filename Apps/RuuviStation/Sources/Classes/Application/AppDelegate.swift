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
    var window: UIWindow?
    var appStateService: AppStateService!
    var localNotificationsManager: RuuviNotificationLocal!
    var featureToggleService: FeatureToggleService!
    var cloudNotificationService: RuuviServiceCloudNotification!
    var pnManager: RuuviCorePN!
    var settings: RuuviLocalSettings!
    var orientationLock = UIInterfaceOrientationMask.allButUpsideDown

    private var appRouter: AppRouter?

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

        window = UIWindow(frame: UIScreen.main.bounds)
        let appRouter = AppRouter()
        appRouter.settings = r.resolve(RuuviLocalSettings.self)
        appRouter.ruuviAnalytics = r.resolve(RuuviAnalytics.self)
        window?.rootViewController = appRouter.viewController
        window?.makeKeyAndVisible()
        self.appRouter = appRouter
        window?.overrideUserInterfaceStyle = settings.theme.uiInterfaceStyle

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        appStateService.applicationWillResignActive(application)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        appStateService.applicationDidEnterBackground(application)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        appStateService.applicationWillEnterForeground(application)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        resetNotificationsBadge()
        appStateService.applicationDidBecomeActive(application)
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

        cloudNotificationService.set(
            token: fcmToken,
            name: UIDevice.modelName,
            data: nil,
            language: settings.language,
            sound: settings.alertSound
        )
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

// MARK: - UniversalLins

extension AppDelegate {
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler _: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL
        else {
            return false
        }
        appStateService.applicationDidOpenWithUniversalLink(application, url: url)
        return true
    }
}

// MARK: - Widget Deeplink Handler

extension AppDelegate {
    func application(
        _ app: UIApplication,
        open url: URL,
        options _: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        let macId = url.absoluteString
        openSelectedCard(for: macId, application: app)
        return true
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
    private func openSelectedCard(
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
    private func resetNotificationsBadge() {
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
