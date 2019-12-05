import Foundation
import UIKit

protocol LocalNotificationsManager: class {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)

    func showDidConnect(uuid: String)
    func showDidDisconnect(uuid: String)
    func notifyLowTemperature(for uuid: String, celsius: Double)
    func notifyHighTemperature(for uuid: String, celsius: Double)
}
