import UIKit
#if canImport(Firebase)
import Firebase
#endif
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var appStateService: AppStateService!
    var localNotificationsManager: LocalNotificationsManager!
    var webTagOperationsManager: WebTagOperationsManager!

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let r = AppAssembly.shared.assembler.resolver
        webTagOperationsManager = r.resolve(WebTagOperationsManager.self)
        if #available(iOS 13, *) {
            // no need to setup background fetch, @see BackgroundTaskServiceiOS13
        } else {
            UIApplication.shared.setMinimumBackgroundFetchInterval(
                   UIApplication.backgroundFetchIntervalMinimum)
        }

        #if canImport(Firebase)
        FirebaseApp.configure()
        #endif

        if let settings = r.resolve(Settings.self),
            settings.welcomeShown {
            let mainRouter = MainRouter.shared
            mainRouter.openCards()
        }
        appStateService = r.resolve(AppStateService.self)
        appStateService.application(application, didFinishLaunchingWithOptions: launchOptions)
        localNotificationsManager = r.resolve(LocalNotificationsManager.self)
        localNotificationsManager.application(application, didFinishLaunchingWithOptions: launchOptions)
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
        if var pnManager = r.resolve(PushNotificationsManager.self) {
            pnManager.pnTokenData = deviceToken
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error.localizedDescription)
    }
}

// MARK: - Background Fetch
extension AppDelegate {
    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if #available(iOS 13, *) {
            completionHandler(.noData)
        } else {
            let operations = webTagOperationsManager.alertsPullOperations()
            enqueueOperations(operations, completionHandler: completionHandler)
        }
    }

    private func enqueueOperations(_ operations: [Operation],
                                   completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if operations.count > 0 {
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            let lastOperation = operations.last!
            lastOperation.completionBlock = {
                completionHandler(.newData)
            }
            queue.addOperations(operations, waitUntilFinished: false)
        } else {
            completionHandler(.noData)
        }
    }
}
