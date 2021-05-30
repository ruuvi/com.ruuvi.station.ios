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
