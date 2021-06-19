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
