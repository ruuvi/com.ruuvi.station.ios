import UIKit

class AppStateServiceImpl: AppStateService {
    
    var broadcastDaemon: RuuviTagBroadcastDaemon!
    var connectionDaemon: RuuviTagConnectionDaemon!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        broadcastDaemon.start()
        connectionDaemon.start()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        broadcastDaemon.stop()
        connectionDaemon.stop()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        broadcastDaemon.start()
        connectionDaemon.start()
    }
}
