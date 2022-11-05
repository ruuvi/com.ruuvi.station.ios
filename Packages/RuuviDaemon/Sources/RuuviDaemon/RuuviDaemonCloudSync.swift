import Foundation

public protocol RuuviDaemonCloudSync {
    func start()
    func stop()
    func refreshImmediately()
    func refreshLatestRecord()
}
