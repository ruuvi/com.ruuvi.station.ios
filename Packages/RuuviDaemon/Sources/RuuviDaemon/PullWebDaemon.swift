import Foundation

public protocol PullWebDaemon {
    func start()
    func stop()
    func wakeUp()
}
