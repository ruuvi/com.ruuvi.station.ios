import UIKit

class AppStateServiceImpl: AppStateService {
    
    var settings: Settings!
    var advertisementDaemon: RuuviTagAdvertisementDaemon!
    var connectionDaemon: RuuviTagConnectionDaemon!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        if settings.isAdvertisementDaemonOn { advertisementDaemon.start() }
        if settings.isConnectionDaemonOn { connectionDaemon.start() }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        if settings.isAdvertisementDaemonOn { advertisementDaemon.stop() }
        if settings.isConnectionDaemonOn { connectionDaemon.stop() }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        if settings.isAdvertisementDaemonOn { advertisementDaemon.start() }
        if settings.isConnectionDaemonOn { connectionDaemon.start() }
    }
}
