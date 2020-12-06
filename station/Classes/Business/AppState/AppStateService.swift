import UIKit

protocol AppStateService {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)
    func applicationWillResignActive(_ application: UIApplication)
    func applicationDidBecomeActive(_ application: UIApplication)
    func applicationDidEnterBackground(_ application: UIApplication)
    func applicationWillEnterForeground(_ application: UIApplication)
    func applicationDidOpenWithUniversalLink(_ application: UIApplication, url: URL)
}
