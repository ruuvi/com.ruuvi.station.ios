import RuuviAnalytics
import RuuviDaemon
import RuuviLocal
import RuuviOntology
import RuuviService
import RuuviUser
import UIKit
#if canImport(WidgetKit)
    import WidgetKit
#endif

class AppStateServiceImpl: AppStateService {
    var advertisementDaemon: RuuviTagAdvertisementDaemon!
    var backgroundProcessService: BackgroundProcessService!
    var heartbeatDaemon: RuuviTagHeartbeatDaemon!
    var ruuviUser: RuuviUser!
    var propertiesDaemon: RuuviTagPropertiesDaemon!
    var cloudSyncDaemon: RuuviDaemonCloudSync!
    var settings: RuuviLocalSettings!
    var userPropertiesService: RuuviAnalytics!
    var universalLinkCoordinator: UniversalLinkCoordinator!

    private var authWillLogoutToken: NSObjectProtocol?
    private var authLogoutCompletionToken: NSObjectProtocol?
    private var daemonsPausedForLogout = false

    private let appGroupDefaults = UserDefaults(
        suiteName: AppGroupConstants.appGroupSuiteIdentifier
    )

    deinit {
        if let token = authWillLogoutToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = authLogoutCompletionToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        if settings.isAdvertisementDaemonOn {
            advertisementDaemon.start()
        }
        if ruuviUser.isAuthorized {
            if !settings.signedInAtleastOnce {
                settings.signedInAtleastOnce = true
            }
        } else {
            ruuviUser.logout()
        }
        heartbeatDaemon.start()
        propertiesDaemon.start()
        backgroundProcessService.register()
        settings.appIsOnForeground = true
        observeWidgetKind()
        DispatchQueue.main.async {
            self.userPropertiesService.update()
        }
        settings.appOpenedCount += 1
        observeAuthLifecycleNotifications()
    }

    func applicationWillResignActive(_: UIApplication) {
        // do nothing yet
    }

    func applicationDidBecomeActive(_: UIApplication) {

        // Start cloud sync daemon only if user is authorized and app is
        // in foreground and active. Otherwise cloud sync daemon can be triggered
        // by other system events that may make the app active in the background
        // such as background scanning.
        if ruuviUser.isAuthorized &&
            settings.appIsOnForeground &&
            !cloudSyncDaemon.isRunning() {
            cloudSyncDaemon.start()
        }

        if let cardToOpen = settings.cardToOpenFromWidget() {
            universalLinkCoordinator.processWidgetLink(macId: cardToOpen)
        }
    }

    func applicationDidEnterBackground(_: UIApplication) {
        if settings.isAdvertisementDaemonOn {
            advertisementDaemon.stop()
        }
        if ruuviUser.isAuthorized {
            cloudSyncDaemon.stop()
#if canImport(WidgetKit)
            // Refresh widgets regardless of interval if user moves the app
            // to background.
            appGroupDefaults?.set(
                true,
                forKey: AppGroupConstants.forceRefreshWidgetKey
            )
            WidgetCenter.shared.reloadTimelines(
                ofKind: AppAssemblyConstants.simpleWidgetKindId
            )
#endif
        }
        propertiesDaemon.stop()
        backgroundProcessService.schedule()
        settings.appIsOnForeground = false
    }

    func applicationWillEnterForeground(_: UIApplication) {
        if settings.isAdvertisementDaemonOn {
            advertisementDaemon.start()
        }
        propertiesDaemon.start()
        settings.appIsOnForeground = true
    }

    func applicationDidOpenWithUniversalLink(_: UIApplication, url: URL) {
        universalLinkCoordinator.processUniversalLink(url: url)
    }

    func applicationDidOpenWithWidgetDeepLink(_: UIApplication?, macId: String) {
        universalLinkCoordinator.processWidgetLink(macId: macId)
    }
}

private extension AppStateServiceImpl {
    func observeWidgetKind() {
        WidgetCenter.shared.getCurrentConfigurations { [weak self] widgetInfos in
            guard case let .success(infos) = widgetInfos else { return }
            let simpleWidgets = infos.filter { $0.kind == AppAssemblyConstants.simpleWidgetKindId }
            self?.settings.useSimpleWidget = simpleWidgets.count > 0
        }
    }

    func observeAuthLifecycleNotifications() {
        if authWillLogoutToken == nil {
            authWillLogoutToken = NotificationCenter.default.addObserver(
                forName: .RuuviAuthServiceWillLogout,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.pauseDaemonsForLogout()
            }
        }
        if authLogoutCompletionToken == nil {
            authLogoutCompletionToken = NotificationCenter.default.addObserver(
                forName: .RuuviAuthServiceLogoutDidFinish,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                let success = (notification.userInfo?[
                    RuuviAuthServiceLogoutDidFinishKey.success.rawValue
                ] as? Bool) ?? false
                self.resumeDaemonsAfterLogout(success: success)
            }
        }
    }

    func pauseDaemonsForLogout() {
        guard !daemonsPausedForLogout else { return }
        daemonsPausedForLogout = true
        if settings.isAdvertisementDaemonOn {
            advertisementDaemon.stop()
        }
        heartbeatDaemon.stop()
        propertiesDaemon.stop()
        cloudSyncDaemon.stop()
    }

    func resumeDaemonsAfterLogout(success: Bool) {
        guard daemonsPausedForLogout else { return }
        daemonsPausedForLogout = false

        if settings.isAdvertisementDaemonOn && settings.appIsOnForeground {
            advertisementDaemon.start()
        }

        heartbeatDaemon.start()

        if settings.appIsOnForeground {
            propertiesDaemon.start()
        }

        if !success && settings.appIsOnForeground {
            if ruuviUser.isAuthorized && !cloudSyncDaemon.isRunning() {
                cloudSyncDaemon.start()
            }
        }
    }
}
