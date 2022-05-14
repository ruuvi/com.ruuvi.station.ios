import UIKit
#if canImport(Firebase)
import Firebase
#endif
#if canImport(FLEX)
import FLEX
#endif
import UserNotifications
import RuuviLocal
import RuuviCore
import RuuviNotification
import RuuviMigration
import RuuviContext

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var appStateService: AppStateService!
    var localNotificationsManager: RuuviNotificationLocal!
    var featureToggleService: FeatureToggleService!
    private var appRouter: AppRouter?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let r = AppAssembly.shared.assembler.resolver

        #if canImport(Firebase)
        FirebaseApp.configure()
        featureToggleService = r.resolve(FeatureToggleService.self)
        featureToggleService.fetchFeatureToggles()
        #endif

        // the order is important
        r.resolve(RuuviMigration.self, name: "realm")?
            .migrateIfNeeded()
        r.resolve(SQLiteContext.self)?
            .database
            .migrateIfNeeded()
        r.resolve(RuuviMigrationFactory.self)?
            .createAllOrdered()
            .forEach({ $0.migrateIfNeeded() })

        appStateService = r.resolve(AppStateService.self)
        appStateService.application(application, didFinishLaunchingWithOptions: launchOptions)
        localNotificationsManager = r.resolve(RuuviNotificationLocal.self)
        let disableTitle = "LocalNotificationsManager.Disable.button".localized()
        let muteTitle = "LocalNotificationsManager.Mute.button".localized()
        localNotificationsManager.setup(
            disableTitle: disableTitle,
            muteTitle: muteTitle
        )

        #if canImport(FLEX)
        FLEXManager.shared.registerGlobalEntry(
            withName: "Feature Toggles",
            viewControllerFutureBlock: { r.resolve(FLEXFeatureTogglesViewController.self) ?? UIViewController()
            }
        )
        #endif

        self.window = UIWindow(frame: UIScreen.main.bounds)
        let appRouter = AppRouter()
        appRouter.settings = r.resolve(RuuviLocalSettings.self)
        self.window?.rootViewController = appRouter.viewController
        self.window?.makeKeyAndVisible()
        self.appRouter = appRouter

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
        appStateService.applicationDidBecomeActive(application)
    }
}

// MARK: - Push Notifications
extension AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let r = AppAssembly.shared.assembler.resolver
        if var pnManager = r.resolve(RuuviCorePN.self) {
            pnManager.pnTokenData = deviceToken
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error.localizedDescription)
    }
}

// MARK: - UniversalLins
extension AppDelegate {
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
           return false
        }
        appStateService.applicationDidOpenWithUniversalLink(application, url: url)
        return true
    }
}

// MARK: - Widget Deeplink Handler
extension AppDelegate {
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        let macId = url.absoluteString
        appStateService.applicationDidOpenWithWidgetDeepLink(app, macId: macId)
        return true
    }
}
