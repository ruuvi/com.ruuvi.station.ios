import UIKit

class AppStateServiceImpl: AppStateService {
    
    var ruuviTagDaemon: RuuviTagDaemon!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        ruuviTagDaemon.startSavingBroadcasts()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        ruuviTagDaemon.stopSavingBroadcasts()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        ruuviTagDaemon.startSavingBroadcasts()
    }
}
