import Foundation
import RuuviStorage
import RuuviCloud
import RuuviPool
import RuuviLocal
import RuuviCore

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
        ruuviPool: RuuviPool,
        propertiesService: RuuviServiceSensorProperties
    ) -> RuuviServiceOwnership

    func createSensorProperties(
        ruuviPool: RuuviPool,
        ruuviCloud: RuuviCloud,
        ruuviCoreImage: RuuviCoreImage,
        ruuviLocalImages: RuuviLocalImages
    ) -> RuuviServiceSensorProperties

    func createSensorRecords(
        ruuviPool: RuuviPool,
        ruuviLocalSyncState: RuuviLocalSyncState
    ) -> RuuviServiceSensorRecords

    func createAppSettings(
        ruuviCloud: RuuviCloud,
        ruuviLocalSettings: RuuviLocalSettings
    ) -> RuuviServiceAppSettings
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
        ruuviPool: RuuviPool,
        propertiesService: RuuviServiceSensorProperties
    ) -> RuuviServiceOwnership {
        return RuuviServiceOwnershipImpl(
            cloud: ruuviCloud,
            pool: ruuviPool,
            propertiesService: propertiesService
        )
    }

    public func createSensorProperties(
        ruuviPool: RuuviPool,
        ruuviCloud: RuuviCloud,
        ruuviCoreImage: RuuviCoreImage,
        ruuviLocalImages: RuuviLocalImages
    ) -> RuuviServiceSensorProperties {
        return RuuviServiceSensorPropertiesImpl(
            pool: ruuviPool,
            cloud: ruuviCloud,
            coreImage: ruuviCoreImage,
            localImages: ruuviLocalImages
        )
    }

    public func createSensorRecords(
        ruuviPool: RuuviPool,
        ruuviLocalSyncState: RuuviLocalSyncState
    ) -> RuuviServiceSensorRecords {
        return RuuviServiceSensorRecordsImpl(
            pool: ruuviPool,
            localSyncState: ruuviLocalSyncState
        )
    }

    public func createAppSettings(
        ruuviCloud: RuuviCloud,
        ruuviLocalSettings: RuuviLocalSettings
    ) -> RuuviServiceAppSettings {
        return RuuviServiceAppSettingsImpl(
            cloud: ruuviCloud,
            localSettings: ruuviLocalSettings
        )
    }
}
