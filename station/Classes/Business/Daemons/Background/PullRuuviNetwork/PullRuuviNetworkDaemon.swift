import Foundation

protocol PullRuuviNetworkDaemon {
    func start()
    func stop()
    func wakeUp()
}
