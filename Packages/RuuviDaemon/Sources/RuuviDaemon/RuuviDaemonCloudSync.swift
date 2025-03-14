import Foundation

public protocol RuuviDaemonCloudSync {
    func start()
    func stop()
    func isRunning() -> Bool
    func refreshImmediately()
    func refreshLatestRecord()
}
