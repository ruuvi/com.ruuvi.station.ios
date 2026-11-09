import RuuviAnalytics
import RuuviLocal
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var appRouter: AppRouter?

    private var appDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }

    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        applyPreferredMinimumSize(to: windowScene)

        let resolver = AppAssembly.shared.assembler.resolver
        let settings = appDelegate?.settings ?? resolver.resolve(RuuviLocalSettings.self)

        let appRouter = AppRouter()
        appRouter.settings = settings
        appRouter.ruuviAnalytics = resolver.resolve(RuuviAnalytics.self)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = appRouter.viewController
        window.overrideUserInterfaceStyle = settings?.theme.uiInterfaceStyle ?? .unspecified
        window.makeKeyAndVisible()
        observeHingeForOrientationLock(on: window)

        self.window = window
        self.appRouter = appRouter

        handleConnectionOptions(connectionOptions)
    }

    func sceneWillEnterForeground(_: UIScene) {
        appDelegate?.appStateService.applicationWillEnterForeground(UIApplication.shared)
    }

    func sceneDidBecomeActive(_: UIScene) {
        appDelegate?.resetNotificationsBadge()
        appDelegate?.appStateService.applicationDidBecomeActive(UIApplication.shared)
    }

    func sceneWillResignActive(_: UIScene) {
        appDelegate?.appStateService.applicationWillResignActive(UIApplication.shared)
    }

    func sceneDidEnterBackground(_: UIScene) {
        appDelegate?.appStateService.applicationDidEnterBackground(UIApplication.shared)
    }

    func scene(_: UIScene, continue userActivity: NSUserActivity) {
        handle(userActivity: userActivity)
    }

    func scene(_: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
        guard let url = urlContexts.first?.url else { return }
        handle(url: url)
    }
}

private extension SceneDelegate {
    /// Asks for windows no narrower than the narrowest iPhone layout without Display Zoom (375 pt),
    /// where the app resizes (iPadOS 27 windows, TN3192). It is only a preference: rotation and the
    /// system can still make the scene narrower, and iPhone SE with Display Zoom is 320 pt wide, so
    /// every screen still has to work below it. No height minimum. A full-screen scene (iPhone,
    /// full-screen iPad) is not affected.
    func applyPreferredMinimumSize(to windowScene: UIWindowScene) {
        windowScene.sizeRestrictions?.minimumSize.width = 375
    }

    /// iPhone Duo: lifts the onboarding / sign in portrait lock while the device is open (inner
    /// display), so the app fills the display instead of showing as a portrait box. Devices without
    /// a hinge (every iPhone and iPad) report a `nil` hinge, so nothing changes there.
    func observeHingeForOrientationLock(on window: UIWindow) {
        guard #available(iOS 27.1, *) else { return }
        window.addInteraction(UIHingeInteraction { _, update in
            guard let hinge = update.hinge else {
                AppUtility.updateFoldableDevice(hasHinge: false, isOpen: false)
                return
            }
            AppUtility.updateFoldableDevice(
                hasHinge: true,
                isOpen: hinge.status == .partiallyOpen || hinge.status == .fullyOpen
            )
        })
    }

    func handleConnectionOptions(_ connectionOptions: UIScene.ConnectionOptions) {
        if let userActivity = connectionOptions.userActivities.first(
            where: { $0.activityType == NSUserActivityTypeBrowsingWeb }
        ) {
            handle(userActivity: userActivity)
        }

        if let url = connectionOptions.urlContexts.first?.url {
            handle(url: url)
        }
    }

    func handle(userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL
        else {
            return
        }

        appDelegate?.appStateService.applicationDidOpenWithUniversalLink(
            UIApplication.shared,
            url: url
        )
    }

    func handle(url: URL) {
        guard let appDelegate else { return }
        let sensorId = appDelegate.widgetSensorIdentifier(from: url)
        appDelegate.openSelectedCard(for: sensorId, application: UIApplication.shared)
    }
}
