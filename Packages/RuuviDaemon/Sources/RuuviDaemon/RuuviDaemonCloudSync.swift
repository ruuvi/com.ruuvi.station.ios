#if SWIFT_PACKAGE
    import RuuviLocal
    import RuuviService
    import RuuviStorage
    import RuuviReactor
    import RuuviPool
    import RuuviPersistence
    import RuuviNotifier
#endif
import Foundation

public protocol RuuviDaemonCloudSync {
    func start()
    func stop()
    func isRunning() -> Bool
    func refreshImmediately()
    func refreshLatestRecord()
}
