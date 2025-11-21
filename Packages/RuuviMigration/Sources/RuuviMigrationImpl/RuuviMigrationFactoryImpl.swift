import RuuviContext
import RuuviLocal
import RuuviPool
import RuuviService
import RuuviStorage

public final class RuuviMigrationFactoryImpl: RuuviMigrationFactory {
    private let settings: RuuviLocalSettings
    private let idPersistence: RuuviLocalIDs
    private let ruuviPool: RuuviPool
    private let sqliteContext: SQLiteContext
    private let ruuviStorage: RuuviStorage
    private let ruuviAlertService: RuuviServiceAlert
    private let ruuviOffsetCalibrationService: RuuviServiceOffsetCalibration

    public init(
        settings: RuuviLocalSettings,
        idPersistence: RuuviLocalIDs,
        ruuviPool: RuuviPool,
        sqliteContext: SQLiteContext,
        ruuviStorage: RuuviStorage,
        ruuviAlertService: RuuviServiceAlert,
        ruuviOffsetCalibrationService: RuuviServiceOffsetCalibration
    ) {
        self.settings = settings
        self.idPersistence = idPersistence
        self.ruuviPool = ruuviPool
        self.sqliteContext = sqliteContext
        self.ruuviStorage = ruuviStorage
        self.ruuviAlertService = ruuviAlertService
        self.ruuviOffsetCalibrationService = ruuviOffsetCalibrationService
    }

    public func createAllOrdered() -> [RuuviMigration] {
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
        let isExcludedFromBackup = MigrationManagerIsExcludedFromBackup(sqliteContext: sqliteContext)
        let signalVisibility = MigrationManagerSignalVisibility(
            ruuviStorage: ruuviStorage,
            ruuviAlertService: ruuviAlertService,
            ruuviPool: ruuviPool,
            ruuviLocalSettings: settings
        )
        return [
            toAlertService,
            toPrune240,
            toChartDuration240,
            toSensorSettings,
            toRH,
            toTimeouts,
            fixRHAlerts,
            toNetworkPull60,
            signalVisibility,
            isExcludedFromBackup,
        ]
    }
}
