import UIKit

class AppStateServiceImpl: AppStateService {
    
    var settings: Settings!
    var advertisementDaemon: RuuviTagAdvertisementDaemon!
    var connectionDaemon: RuuviTagConnectionDaemon!
    var webTagDaemon: WebTagDaemon!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        if settings.isAdvertisementDaemonOn { advertisementDaemon.start() }
        if settings.isConnectionDaemonOn { connectionDaemon.start() }
        if settings.isWebTagDaemonOn { webTagDaemon.start() }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        if settings.isAdvertisementDaemonOn { advertisementDaemon.stop() }
        if settings.isConnectionDaemonOn { connectionDaemon.stop() }
        if settings.isWebTagDaemonOn { webTagDaemon.stop() }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        if settings.isAdvertisementDaemonOn { advertisementDaemon.start() }
        if settings.isConnectionDaemonOn { connectionDaemon.start() }
        if settings.isWebTagDaemonOn { webTagDaemon.start() }
    }
}
