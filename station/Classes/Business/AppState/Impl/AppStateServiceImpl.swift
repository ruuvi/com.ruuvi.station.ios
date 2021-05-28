import UIKit
import RuuviLocal

class AppStateServiceImpl: AppStateService {

    var advertisementDaemon: RuuviTagAdvertisementDaemon!
    var backgroundTaskService: BackgroundTaskService!
    var backgroundProcessService: BackgroundProcessService!
    var heartbeatDaemon: RuuviTagHeartbeatDaemon!
    var keychainService: KeychainService!
    var propertiesDaemon: RuuviTagPropertiesDaemon!
    var pullWebDaemon: PullWebDaemon!
    var pullNetworkTagDaemon: PullRuuviNetworkDaemon!
    var settings: RuuviLocalSettings!
    var userPropertiesService: UserPropertiesService!
    var universalLinkCoordinator: UniversalLinkCoordinator!
    var webTagDaemon: WebTagDaemon!

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        if settings.isAdvertisementDaemonOn {
            advertisementDaemon.start()
        }
        if settings.isWebTagDaemonOn {
            webTagDaemon.start()
        }
        if keychainService.userIsAuthorized {
            pullNetworkTagDaemon.start()
        } else if keychainService.ruuviUserApiKey != nil
                    && keychainService.userApiEmail != nil {
            keychainService.userApiLogOut()
        }
        heartbeatDaemon.start()
        propertiesDaemon.start()
        pullWebDaemon.start()
        backgroundTaskService.register()
        backgroundProcessService.register()
        DispatchQueue.main.async {
            self.userPropertiesService.update()
        }
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
        if keychainService.userIsAuthorized {
            pullNetworkTagDaemon.stop()
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
        if keychainService.userIsAuthorized {
            pullNetworkTagDaemon.start()
            pullNetworkTagDaemon.refreshImmediately()
        }
        propertiesDaemon.start()
        pullWebDaemon.start()
        backgroundProcessService.launch()
    }

    func applicationDidOpenWithUniversalLink(_ application: UIApplication, url: URL) {
        universalLinkCoordinator.processUniversalLink(url: url)
    }
}
