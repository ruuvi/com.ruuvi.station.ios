import UIKit
import RuuviLocal
import RuuviDaemon
import RuuviUser
import RuuviOntology
#if canImport(RuuviAnalytics)
import RuuviAnalytics
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

class AppStateServiceImpl: AppStateService {
    var advertisementDaemon: RuuviTagAdvertisementDaemon!
    var backgroundTaskService: BackgroundTaskService!
    var backgroundProcessService: BackgroundProcessService!
    var heartbeatDaemon: RuuviTagHeartbeatDaemon!
    var ruuviUser: RuuviUser!
    var propertiesDaemon: RuuviTagPropertiesDaemon!
    var pullWebDaemon: PullWebDaemon!
    var cloudSyncDaemon: RuuviDaemonCloudSync!
    var settings: RuuviLocalSettings!
    #if canImport(RuuviAnalytics)
    var userPropertiesService: RuuviAnalytics!
    #endif
    var universalLinkCoordinator: UniversalLinkCoordinator!
    var webTagDaemon: VirtualTagDaemon!

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        if settings.isAdvertisementDaemonOn {
            advertisementDaemon.start()
        }
        if settings.isWebTagDaemonOn {
            webTagDaemon.start()
        }
        if ruuviUser.isAuthorized {
            cloudSyncDaemon.start()
            cloudSyncDaemon.refreshImmediately()
        } else {
            ruuviUser.logout()
        }
        heartbeatDaemon.start()
        propertiesDaemon.start()
        pullWebDaemon.start()
        backgroundTaskService.register()
        backgroundProcessService.register()
        settings.appIsOnForeground = true
        observeWidgetKind()
        #if canImport(RuuviAnalytics)
        DispatchQueue.main.async {
            self.userPropertiesService.update()
        }
        settings.appOpenedCount += 1
        #endif
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // do nothing yet
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // do nothing yet
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        if settings.isAdvertisementDaemonOn {
            advertisementDaemon.stop()
        }
        if settings.isWebTagDaemonOn {
            webTagDaemon.stop()
        }
        if ruuviUser.isAuthorized {
            cloudSyncDaemon.stop()
            WidgetCenter.shared.reloadTimelines(ofKind: AppAssemblyConstants.simpleWidgetKindId)
        }
        propertiesDaemon.stop()
        pullWebDaemon.stop()
        backgroundTaskService.schedule()
        backgroundProcessService.schedule()
        settings.appIsOnForeground = false
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        if settings.isAdvertisementDaemonOn {
            advertisementDaemon.start()
        }
        if settings.isWebTagDaemonOn {
            webTagDaemon.start()
        }
        if ruuviUser.isAuthorized {
            cloudSyncDaemon.start()
            cloudSyncDaemon.refreshImmediately()
        }
        propertiesDaemon.start()
        pullWebDaemon.start()
        settings.appIsOnForeground = true
    }

    func applicationDidOpenWithUniversalLink(_ application: UIApplication, url: URL) {
        universalLinkCoordinator.processUniversalLink(url: url)
    }

    func applicationDidOpenWithWidgetDeepLink(_ application: UIApplication, macId: String) {
        universalLinkCoordinator.processWidgetLink(macId: macId)
    }
}

extension AppStateServiceImpl {
    fileprivate func observeWidgetKind() {
        WidgetCenter.shared.getCurrentConfigurations { [weak self] widgetInfos in
            guard case .success(let infos) = widgetInfos else { return }
            let simpleWidgets = infos.filter({ $0.kind == AppAssemblyConstants.simpleWidgetKindId })
            self?.settings.useSimpleWidget = simpleWidgets.count > 0
        }
    }
}
