import RuuviAnalytics
import RuuviDaemon
import RuuviLocal
import RuuviOntology
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

    private let appGroupDefaults = UserDefaults(
        suiteName: AppGroupConstants.appGroupSuiteIdentifier
    )

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
        if settings.saveHeartbeats {
            heartbeatDaemon.restart()
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
}
