#if SWIFT_PACKAGE
    import RuuviStorage
    import RuuviReactor
    import RuuviPool
    import RuuviPersistence
    import RuuviNotifier
#endif
import Foundation
import RuuviLocal
import RuuviService

public protocol RuuviDaemonFactory {
    func createCloudSync(
        localSettings: RuuviLocalSettings,
        localSyncState: RuuviLocalSyncState,
        cloudSyncService: RuuviServiceCloudSync
    ) -> RuuviDaemonCloudSync
}
