import UIKit
import Firebase
#if canImport(FLEX)
import FLEX
#endif
import UserNotifications
import RuuviLocal
import RuuviCore
import RuuviNotification
import RuuviMigration
import RuuviContext
import RuuviService
import RuuviOntology

@UIApplicationMain
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

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let r = AppAssembly.shared.assembler.resolver
        self.settings = r.resolve(RuuviLocalSettings.self)
        setPreferrerdLanguage()

        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        pnManager = r.resolve(RuuviCorePN.self)

        featureToggleService = r.resolve(FeatureToggleService.self)
        featureToggleService.fetchFeatureToggles()

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
            muteTitle: muteTitle,
            output: self
        )

        cloudNotificationService = r.resolve(RuuviServiceCloudNotification.self)

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
        self.window?.overrideUserInterfaceStyle = settings.theme.uiInterfaceStyle

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

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return orientationLock
  }
}

// MARK: - Push Notifications
extension AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        Messaging.messaging().apnsToken = deviceToken
        pnManager.pnTokenData = deviceToken

        Messaging.messaging().token { [weak self] fcmToken, _ in
            self?.register(with: fcmToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error.localizedDescription)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        register(with: fcmToken)
    }

    private func register(with fcmToken: String?) {
        guard !UIDevice.isSimulator,
                let fcmToken = fcmToken,
                cloudNotificationService != nil else {
            return
        }

        cloudNotificationService.set(token: fcmToken,
                                     name: UIDevice.modelName,
                                     data: nil,
                                     language: settings.language,
                                     sound: settings.alertSound)
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
    private func openSelectedCard(for uuid: String,
                                  application: UIApplication? = nil) {
        appRouter?.prepareRootViewControllerWidgets()
        window?.rootViewController = appRouter?.viewController

        if let navigationController = appRouter?.viewController as? UINavigationController,
           let controller = navigationController.viewControllers.last as? DashboardViewController {
            if let viewModel = controller.viewModels.first(where: { viewModel in
                viewModel.mac.value?.value == uuid || viewModel.luid.value == uuid.luid.any
            }) {
                controller.output.viewDidTriggerOpenCardImageView(for: viewModel)
            }
        }

        window?.makeKeyAndVisible()
    }
}
