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

    func createOwnership(
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool
    ) -> RuuviServiceOwnership
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

    public func createOwnership(
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool
    ) -> RuuviServiceOwnership {
        return RuuviServiceOwnershipImpl(cloud: ruuviCloud, pool: ruuviPool)
    }
}
