import Foundation
import RuuviStorage
import RuuviCloud
import RuuviPool
import RuuviLocal
import RuuviCore
import RuuviRepository

public protocol RuuviServiceFactory {
    // swiftlint:disable:next function_parameter_count
    func createCloudSync(
        ruuviStorage: RuuviStorage,
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        ruuviLocalSettings: RuuviLocalSettings,
        ruuviLocalSyncState: RuuviLocalSyncState,
        ruuviLocalImages: RuuviLocalImages,
        ruuviRepository: RuuviRepository,
        ruuviLocalIDs: RuuviLocalIDs
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

    func createOffsetCalibration(
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool
    ) -> RuuviServiceOffsetCalibration

    func createAlert(
        ruuviCloud: RuuviCloud
    ) -> RuuviServiceAlert
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
        ruuviLocalImages: RuuviLocalImages,
        ruuviRepository: RuuviRepository,
        ruuviLocalIDs: RuuviLocalIDs
    ) -> RuuviServiceCloudSync {
        return RuuviServiceCloudSyncImpl(
            ruuviStorage: ruuviStorage,
            ruuviCloud: ruuviCloud,
            ruuviPool: ruuviPool,
            ruuviLocalSettings: ruuviLocalSettings,
            ruuviLocalSyncState: ruuviLocalSyncState,
            ruuviLocalImages: ruuviLocalImages,
            ruuviRepository: ruuviRepository,
            ruuviLocalIDs: ruuviLocalIDs
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

    public func createOffsetCalibration(
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool
    ) -> RuuviServiceOffsetCalibration {
        return RuuviServiceAppOffsetCalibrationImpl(
            cloud: ruuviCloud,
            pool: ruuviPool
        )
    }

    public func createAlert(
        ruuviCloud: RuuviCloud
    ) -> RuuviServiceAlert {
        return RuuviServiceAlertImpl(cloud: ruuviCloud)
    }
}
