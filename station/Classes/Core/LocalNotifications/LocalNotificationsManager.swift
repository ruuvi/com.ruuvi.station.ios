import Foundation
import UIKit

protocol LocalNotificationsManager: class {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?)

    func showDidConnect(uuid: String)
    func showDidDisconnect(uuid: String)
    func notifyLowTemperature(for uuid: String, celsius: Double)
    func notifyHighTemperature(for uuid: String, celsius: Double)
    func notifyLowRelativeHumidity(for uuid: String, relativeHumidity: Double)
    func notifyHighRelativeHumidity(for uuid: String, relativeHumidity: Double)
    func notifyLowAbsoluteHumidity(for uuid: String, absoluteHumidity: Double)
    func notifyHighAbsoluteHumidity(for uuid: String, absoluteHumidity: Double)
    func notifyLowDewPoint(for uuid: String, dewPointCelsius: Double)
    func notifyHighDewPoint(for uuid: String, dewPointCelsius: Double)
    func notifyLowPressure(for uuid: String, pressure: Double)
    func notifyHighPressure(for uuid: String, pressure: Double)
}
