import Foundation
import RuuviStorage
import RuuviCloud
import RuuviPool
import RuuviLocal

public protocol RuuviServiceFactory {
    // swiftlint:disable:next function_parameter_count
    func createCloudSync(
        ruuviStorage: RuuviStorage,
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        ruuviLocalSettings: RuuviLocalSettings,
        ruuviLocalSyncState: RuuviLocalSyncState,
        ruuviLocalImages: RuuviLocalImages
    ) -> RuuviServiceCloudSync
}

public final class RuuviServiceFactoryImpl: RuuviServiceFactory {
    public init() {}

    // swiftlint:disable:next function_parameter_count
    public func createCloudSync(
        ruuviStorage: RuuviStorage,
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        ruuviLocalSettings: RuuviLocalSettings,
        ruuviLocalSyncState: RuuviLocalSyncState,
        ruuviLocalImages: RuuviLocalImages
    ) -> RuuviServiceCloudSync {
        return RuuviServiceCloudSyncImpl(
            ruuviStorage: ruuviStorage,
            ruuviCloud: ruuviCloud,
            ruuviPool: ruuviPool,
            ruuviLocalSettings: ruuviLocalSettings,
            ruuviLocalSyncState: ruuviLocalSyncState,
            ruuviLocalImages: ruuviLocalImages
        )
    }
}
