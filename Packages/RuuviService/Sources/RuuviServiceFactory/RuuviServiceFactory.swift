import Foundation
import RuuviCloud
import RuuviCore
import RuuviLocal
import RuuviPool
import RuuviRepository
import RuuviStorage
import RuuviUser

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
        ruuviAlertService: RuuviServiceAlert,
        ruuviAppSettingsService: RuuviServiceAppSettings
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
        ruuviLocalIDs: RuuviLocalIDs,
        ruuviLocalSettings: RuuviLocalSettings
    ) -> RuuviServiceAlert

    // swiftlint:disable:next function_parameter_count
    func createAuth(
        ruuviUser: RuuviUser,
        pool: RuuviPool,
        storage: RuuviStorage,
        propertiesService: RuuviServiceSensorProperties,
        localIDs: RuuviLocalIDs,
        localSyncState: RuuviLocalSyncState,
        alertService: RuuviServiceAlert
    ) -> RuuviServiceAuth

    func createCloudNotification(
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        storage: RuuviStorage,
        ruuviUser: RuuviUser,
        pnManager: RuuviCorePN
    ) -> RuuviServiceCloudNotification
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
        ruuviAlertService: RuuviServiceAlert,
        ruuviAppSettingsService: RuuviServiceAppSettings
    ) -> RuuviServiceCloudSync {
        RuuviServiceCloudSyncImpl(
            ruuviStorage: ruuviStorage,
            ruuviCloud: ruuviCloud,
            ruuviPool: ruuviPool,
            ruuviLocalSettings: ruuviLocalSettings,
            ruuviLocalSyncState: ruuviLocalSyncState,
            ruuviLocalImages: ruuviLocalImages,
            ruuviRepository: ruuviRepository,
            ruuviLocalIDs: ruuviLocalIDs,
            ruuviAlertService: ruuviAlertService,
            ruuviAppSettingsService: ruuviAppSettingsService
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
        RuuviServiceOwnershipImpl(
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
        RuuviServiceSensorPropertiesImpl(
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
        RuuviServiceSensorRecordsImpl(
            pool: ruuviPool,
            localSyncState: ruuviLocalSyncState
        )
    }

    public func createAppSettings(
        ruuviCloud: RuuviCloud,
        ruuviLocalSettings: RuuviLocalSettings
    ) -> RuuviServiceAppSettings {
        RuuviServiceAppSettingsImpl(
            cloud: ruuviCloud,
            localSettings: ruuviLocalSettings
        )
    }

    public func createOffsetCalibration(
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool
    ) -> RuuviServiceOffsetCalibration {
        RuuviServiceAppOffsetCalibrationImpl(
            cloud: ruuviCloud,
            pool: ruuviPool
        )
    }

    public func createAlert(
        ruuviCloud: RuuviCloud,
        ruuviLocalIDs: RuuviLocalIDs,
        ruuviLocalSettings: RuuviLocalSettings
    ) -> RuuviServiceAlert {
        RuuviServiceAlertImpl(
            cloud: ruuviCloud,
            localIDs: ruuviLocalIDs,
            ruuviLocalSettings: ruuviLocalSettings
        )
    }

    // swiftlint:disable:next function_parameter_count
    public func createAuth(
        ruuviUser: RuuviUser,
        pool: RuuviPool,
        storage: RuuviStorage,
        propertiesService: RuuviServiceSensorProperties,
        localIDs: RuuviLocalIDs,
        localSyncState: RuuviLocalSyncState,
        alertService: RuuviServiceAlert
    ) -> RuuviServiceAuth {
        RuuviServiceAuthImpl(
            ruuviUser: ruuviUser,
            pool: pool,
            storage: storage,
            propertiesService: propertiesService,
            localIDs: localIDs,
            localSyncState: localSyncState,
            alertService: alertService
        )
    }

    public func createCloudNotification(
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        storage: RuuviStorage,
        ruuviUser: RuuviUser,
        pnManager: RuuviCorePN
    ) -> RuuviServiceCloudNotification {
        RuuviServiceCloudNotificationImpl(
            cloud: ruuviCloud,
            pool: ruuviPool,
            storage: storage,
            ruuviUser: ruuviUser,
            pnManager: pnManager
        )
    }
}
