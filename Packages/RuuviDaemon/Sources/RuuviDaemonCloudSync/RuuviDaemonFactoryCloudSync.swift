import Foundation
import RuuviDaemon
import RuuviLocal
import RuuviService

public final class RuuviDaemonFactoryImpl: RuuviDaemonFactory {
    public init() {}

    public func createCloudSync(
        localSettings: RuuviLocalSettings,
        localSyncState: RuuviLocalSyncState,
        cloudSyncService: RuuviServiceCloudSync
    ) -> RuuviDaemonCloudSync {
        RuuviDaemonCloudSyncWorker(
            localSettings: localSettings,
            localSyncState: localSyncState,
            cloudSyncService: cloudSyncService
        )
    }
}
