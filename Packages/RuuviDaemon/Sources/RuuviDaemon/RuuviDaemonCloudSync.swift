import Foundation

public protocol RuuviDaemonCloudSync {
    func start()
    func stop()
    func refreshImmediately()
    func refreshRecords(latestOnly: Bool)
}
