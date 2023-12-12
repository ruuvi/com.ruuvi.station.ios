import RuuviDaemon
import RuuviLocal
import RuuviOntology
import RuuviUser
import UIKit
#if canImport(RuuviAnalytics)
    import RuuviAnalytics
#endif
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
    #if canImport(RuuviAnalytics)
        var userPropertiesService: RuuviAnalytics!
    #endif
    var universalLinkCoordinator: UniversalLinkCoordinator!

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        if settings.isAdvertisementDaemonOn {
            advertisementDaemon.start()
        }
        if ruuviUser.isAuthorized {
            cloudSyncDaemon.start()

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
        #if canImport(RuuviAnalytics)
            DispatchQueue.main.async {
                self.userPropertiesService.update()
            }
            settings.appOpenedCount += 1
        #endif
    }

    func applicationWillResignActive(_: UIApplication) {
        // do nothing yet
    }

    func applicationDidBecomeActive(_: UIApplication) {
        // do nothing yet
    }

    func applicationDidEnterBackground(_: UIApplication) {
        if settings.isAdvertisementDaemonOn {
            advertisementDaemon.stop()
        }
        if ruuviUser.isAuthorized {
            cloudSyncDaemon.stop()
            WidgetCenter.shared.reloadTimelines(ofKind: AppAssemblyConstants.simpleWidgetKindId)
        }
        propertiesDaemon.stop()
        backgroundProcessService.schedule()
        settings.appIsOnForeground = false
    }

    func applicationWillEnterForeground(_: UIApplication) {
        if settings.isAdvertisementDaemonOn {
            advertisementDaemon.start()
        }
        if ruuviUser.isAuthorized {
            cloudSyncDaemon.start()
        }
        propertiesDaemon.start()
        settings.appIsOnForeground = true
    }

    func applicationDidOpenWithUniversalLink(_: UIApplication, url: URL) {
        universalLinkCoordinator.processUniversalLink(url: url)
    }

    func applicationDidOpenWithWidgetDeepLink(_: UIApplication, macId: String) {
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
