import Foundation

protocol LocalNotificationsManager {
    func showDidConnect(uuid: String)
    func showDidDisconnect(uuid: String)
}
