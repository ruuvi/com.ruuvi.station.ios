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

        let resolver = AppAssembly.shared.assembler.resolver
        let settings = appDelegate?.settings ?? resolver.resolve(RuuviLocalSettings.self)

        let appRouter = AppRouter()
        appRouter.settings = settings
        appRouter.ruuviAnalytics = resolver.resolve(RuuviAnalytics.self)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = appRouter.viewController
        window.overrideUserInterfaceStyle = settings?.theme.uiInterfaceStyle ?? .unspecified
        window.makeKeyAndVisible()

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
