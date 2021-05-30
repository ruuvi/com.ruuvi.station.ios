import Foundation

public protocol RuuviDaemonCloudSync {
    func start()
    func stop()
    func wakeUp()
    func refreshImmediately()
}
