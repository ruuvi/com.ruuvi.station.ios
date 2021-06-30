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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var appStateService: AppStateService!
    var localNotificationsManager: RuuviNotificationLocal!
    var featureToggleService: FeatureToggleService!

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let r = AppAssembly.shared.assembler.resolver

        #if canImport(Firebase)
        FirebaseApp.configure()
        featureToggleService = r.resolve(FeatureToggleService.self)
        featureToggleService.fetchFeatureToggles()
        #endif

        if let settings = r.resolve(RuuviLocalSettings.self),
            settings.welcomeShown {
            let mainRouter = MainRouter.shared
            mainRouter.openCards()
        }
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
