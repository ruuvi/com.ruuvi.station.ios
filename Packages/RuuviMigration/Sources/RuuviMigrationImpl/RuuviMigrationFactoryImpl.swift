import RuuviLocal
import RuuviPool
import RuuviContext
import RuuviStorage
import RuuviService
import RuuviMigration

public final class RuuviMigrationFactoryImpl: RuuviMigrationFactory {
    private let settings: RuuviLocalSettings
    private let idPersistence: RuuviLocalIDs
    private let realmContext: RealmContext
    private let ruuviPool: RuuviPool
    private let ruuviStorage: RuuviStorage
    private let ruuviAlertService: RuuviServiceAlert
    private let ruuviOffsetCalibrationService: RuuviServiceOffsetCalibration

    public init(
        settings: RuuviLocalSettings,
        idPersistence: RuuviLocalIDs,
        realmContext: RealmContext,
        ruuviPool: RuuviPool,
        ruuviStorage: RuuviStorage,
        ruuviAlertService: RuuviServiceAlert,
        ruuviOffsetCalibrationService: RuuviServiceOffsetCalibration
    ) {
        self.settings = settings
        self.idPersistence = idPersistence
        self.realmContext = realmContext
        self.ruuviPool = ruuviPool
        self.ruuviStorage = ruuviStorage
        self.ruuviAlertService = ruuviAlertService
        self.ruuviOffsetCalibrationService = ruuviOffsetCalibrationService
    }

    public func createAllOrdered() -> [RuuviMigration] {
        let toSQLite = MigrationManagerToSQLite(
            idPersistence: idPersistence,
            realmContext: realmContext,
            ruuviPool: ruuviPool
        )
        let toAlertService = MigrationManagerAlertService(
            ruuviStorage: ruuviStorage,
            ruuviAlertService: ruuviAlertService
        )
        let toPrune240 = MigrationManagerToPrune240(settings: settings)
        let toChartDuration240 = MigrationManagerToChartDuration240(settings: settings)
        let toSensorSettings = MigrationManagerSensorSettings(
            calibrationPersistence: CalibrationPersistenceUserDefaults(),
            ruuviStorage: ruuviStorage,
            ruuviOffsetCalibrationService: ruuviOffsetCalibrationService
        )
        let toRH = MigrationManagerToRH(
            ruuviStorage: ruuviStorage,
            ruuviAlertService: ruuviAlertService
        )
        let toTimeouts = MigrationManagerToTimeouts(settings: settings)
        let fixRHAlerts = RuuviMigrationFixRHAlerts(
            ruuviStorage: ruuviStorage,
            ruuviAlertService: ruuviAlertService
        )
        let toNetworkPull60 = MigrationManagerToNetworkPull60(settings: settings)
        return [toSQLite,
                toAlertService,
                toPrune240,
                toChartDuration240,
                toSensorSettings,
                toRH,
                toTimeouts,
                fixRHAlerts,
                toNetworkPull60]
    }
}
