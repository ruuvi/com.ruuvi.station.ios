import UIKit
import RuuviLocal
import RuuviDaemon
import RuuviUser
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
        }
        heartbeatDaemon.start()
        propertiesDaemon.start()
        pullWebDaemon.start()
        backgroundTaskService.register()
        backgroundProcessService.register()
        #if canImport(RuuviAnalytics)
        DispatchQueue.main.async {
            self.userPropertiesService.update()
        }
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
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadTimelines(ofKind: "ruuvi.simpleWidget")
            }
        }
        propertiesDaemon.stop()
        pullWebDaemon.stop()
        backgroundTaskService.schedule()
        backgroundProcessService.schedule()
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
    }

    func applicationDidOpenWithUniversalLink(_ application: UIApplication, url: URL) {
        universalLinkCoordinator.processUniversalLink(url: url)
    }

    func applicationDidOpenWithWidgetDeepLink(_ application: UIApplication, macId: String) {
        NotificationCenter.default.post(name: .DidOpenWithWidgetDeepLink,
                                        object: nil,
                                        userInfo: [WidgetDeepLinkMacIdKey.macId: macId])
    }
}
