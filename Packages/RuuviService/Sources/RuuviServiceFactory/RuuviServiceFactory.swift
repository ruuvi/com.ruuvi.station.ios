import Foundation
import RuuviStorage
import RuuviCloud
import RuuviPool
import RuuviLocal
import RuuviCore
import RuuviRepository
import RuuviService
import RuuviUser
#if canImport(RuuviServiceAlert)
import RuuviServiceAlert
#endif
#if canImport(RuuviServiceCloudSync)
import RuuviServiceCloudSync
#endif
#if canImport(RuuviServiceOwnership)
import RuuviServiceOwnership
#endif
#if canImport(RuuviServiceAppSettings)
import RuuviServiceAppSettings
#endif
#if canImport(RuuviServiceSensorRecords)
import RuuviServiceSensorRecords
#endif
#if canImport(RuuviServiceSensorProperties)
import RuuviServiceSensorProperties
#endif
#if canImport(RuuviServiceOffsetCalibration)
import RuuviServiceOffsetCalibration
#endif

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

    // swiftlint:disable:next function_parameter_count
    func createOwnership(
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        propertiesService: RuuviServiceSensorProperties,
        localIDs: RuuviLocalIDs,
        localImages: RuuviLocalImages,
        storage: RuuviStorage,
        alertService: RuuviServiceAlert,
        ruuviUser: RuuviUser
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

    // swiftlint:disable:next function_parameter_count
    public func createOwnership(
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        propertiesService: RuuviServiceSensorProperties,
        localIDs: RuuviLocalIDs,
        localImages: RuuviLocalImages,
        storage: RuuviStorage,
        alertService: RuuviServiceAlert,
        ruuviUser: RuuviUser
    ) -> RuuviServiceOwnership {
        return RuuviServiceOwnershipImpl(
            cloud: ruuviCloud,
            pool: ruuviPool,
            propertiesService: propertiesService,
            localIDs: localIDs,
            localImages: localImages,
            storage: storage,
            alertService: alertService,
            ruuviUser: ruuviUser
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
