import Foundation

protocol LocalNotificationsManager {
    func showDidConnect(uuid: String)
    func showDidDisconnect(uuid: String)
    func notifyLowTemperature(for uuid: String, celsius: Double)
    func notifyHighTemperature(for uuid: String, celsius: Double)
}
