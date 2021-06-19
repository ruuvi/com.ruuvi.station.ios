import Foundation
import RuuviLocal
import RuuviService
import RuuviDaemon

public final class RuuviDaemonFactoryImpl: RuuviDaemonFactory {
    public init() {}

    public func createCloudSync(
        localSettings: RuuviLocalSettings,
        localSyncState: RuuviLocalSyncState,
        cloudSyncService: RuuviServiceCloudSync
    ) -> RuuviDaemonCloudSync {
        return RuuviDaemonCloudSyncWorker(
            localSettings: localSettings,
            localSyncState: localSyncState,
            cloudSyncService: cloudSyncService
        )
    }
}
