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
        ruuviLocalIDs: RuuviLocalIDs,
        ruuviAlertService: RuuviServiceAlert
    ) -> RuuviServiceCloudSync

    func createOwnership(
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        propertiesService: RuuviServiceSensorProperties,
        localIDs: RuuviLocalIDs
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
        ruuviCloud: RuuviCloud,
        ruuviLocalIDs: RuuviLocalIDs
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
        ruuviLocalIDs: RuuviLocalIDs,
        ruuviAlertService: RuuviServiceAlert
    ) -> RuuviServiceCloudSync {
        return RuuviServiceCloudSyncImpl(
            ruuviStorage: ruuviStorage,
            ruuviCloud: ruuviCloud,
            ruuviPool: ruuviPool,
            ruuviLocalSettings: ruuviLocalSettings,
            ruuviLocalSyncState: ruuviLocalSyncState,
            ruuviLocalImages: ruuviLocalImages,
            ruuviRepository: ruuviRepository,
            ruuviLocalIDs: ruuviLocalIDs,
            ruuviAlertService: ruuviAlertService
        )
    }

    public func createOwnership(
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        propertiesService: RuuviServiceSensorProperties,
        localIDs: RuuviLocalIDs
    ) -> RuuviServiceOwnership {
        return RuuviServiceOwnershipImpl(
            cloud: ruuviCloud,
            pool: ruuviPool,
            propertiesService: propertiesService,
            localIDs: localIDs
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
        ruuviCloud: RuuviCloud,
        ruuviLocalIDs: RuuviLocalIDs
    ) -> RuuviServiceAlert {
        return RuuviServiceAlertImpl(
            cloud: ruuviCloud,
            localIDs: ruuviLocalIDs
        )
    }
}
