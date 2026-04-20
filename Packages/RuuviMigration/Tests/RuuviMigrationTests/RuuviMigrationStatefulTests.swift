@testable import RuuviLocal
@testable import RuuviMigration
import GRDB
import Humidity
import RuuviCloud
import RuuviContext
import RuuviOntology
import RuuviPool
import RuuviService
import RuuviStorage
import UIKit
import XCTest

final class RuuviMigrationStatefulTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetMigrationUserDefaults()
    }

    func testFactoryCreatesManagersInExpectedOrder() {
        let settings = makeMigrationSettings()
        let factory = RuuviMigrationFactoryImpl(
            settings: settings,
            idPersistence: RuuviLocalIDsUserDefaults(),
            ruuviPool: PoolSpy(),
            ruuviSensorProperties: SensorPropertiesSpy(),
            sqliteContext: SQLiteContextSpy(dbPath: makeTemporaryDatabasePath()),
            ruuviStorage: StorageSpy(),
            ruuviAlertService: makeMigrationAlertService(settings: settings),
            ruuviOffsetCalibrationService: OffsetCalibrationSpy()
        )

        let names = factory.createAllOrdered().map { String(describing: type(of: $0)) }

        XCTAssertEqual(
            names,
            [
                "MigrationManagerAlertService",
                "MigrationManagerToPrune240",
                "MigrationManagerToChartDuration240",
                "MigrationManagerSensorSettings",
                "MigrationManagerToRH",
                "MigrationManagerToTimeouts",
                "RuuviMigrationFixRHAlerts",
                "MigrationManagerToNetworkPull60",
                "MigrationManagerSignalVisibility",
                "MigrationManagerIsExcludedFromBackup",
            ]
        )
    }

    func testSettingsMigrationsAreOneShot() {
        let settings = makeMigrationSettings()
        let prune = MigrationManagerToPrune240(settings: settings)
        let chart = MigrationManagerToChartDuration240(settings: settings)
        let timeouts = MigrationManagerToTimeouts(settings: settings)
        let networkPull = MigrationManagerToNetworkPull60(settings: settings)

        prune.migrateIfNeeded()
        chart.migrateIfNeeded()
        timeouts.migrateIfNeeded()
        networkPull.migrateIfNeeded()

        XCTAssertEqual(settings.dataPruningOffsetHours, 240)
        XCTAssertEqual(settings.chartDurationHours, 240)
        XCTAssertEqual(settings.connectionTimeout, 30)
        XCTAssertEqual(settings.serviceTimeout, 60)
        XCTAssertEqual(settings.networkPullIntervalSeconds, 60)

        settings.dataPruningOffsetHours = 1
        settings.chartDurationHours = 1
        settings.connectionTimeout = 1
        settings.serviceTimeout = 1
        settings.networkPullIntervalSeconds = 1

        prune.migrateIfNeeded()
        chart.migrateIfNeeded()
        timeouts.migrateIfNeeded()
        networkPull.migrateIfNeeded()

        XCTAssertEqual(settings.dataPruningOffsetHours, 1)
        XCTAssertEqual(settings.chartDurationHours, 1)
        XCTAssertEqual(settings.connectionTimeout, 1)
        XCTAssertEqual(settings.serviceTimeout, 1)
        XCTAssertEqual(settings.networkPullIntervalSeconds, 1)
    }

    func testSensorSettingsMigrationMovesHumidityOffsetsIntoOffsetServiceAndClearsLegacyPersistence() {
        let sensor = makeMigrationSensor()
        let calibration = CalibrationPersistenceSpy()
        calibration.offsets[sensor.luid!.value] = (25, Date())
        let storage = StorageSpy()
        storage.readAllResult = [sensor.any]
        let offsetService = OffsetCalibrationSpy()
        let sut = MigrationManagerSensorSettings(
            calibrationPersistence: calibration,
            ruuviStorage: storage,
            ruuviOffsetCalibrationService: offsetService
        )

        sut.migrateIfNeeded()
        waitUntil {
            offsetService.calls.count == 1 && calibration.setCalls.count == 1
        }

        XCTAssertEqual(offsetService.calls.first?.sensor.id, sensor.id)
        XCTAssertEqual(offsetService.calls.first?.type, .humidity)
        XCTAssertEqual(offsetService.calls.first?.offset ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertEqual(calibration.setCalls.first?.0.value, sensor.luid?.value)
        XCTAssertEqual(calibration.setCalls.first?.1 ?? 1, 0, accuracy: 0.0001)

        sut.migrateIfNeeded()
        waitUntil { offsetService.calls.count == 1 }
    }

    func testSignalVisibilityMigrationAddsSignalCodeForOwnerAlertsAndFinishesCleanly() {
        let settings = makeMigrationSettings()
        let sensor = makeMigrationSensor(version: 5, isOwner: true)
        let storage = StorageSpy()
        storage.readAllResult = [sensor.any]
        let properties = SensorPropertiesSpy()
        let alertService = makeMigrationAlertService(settings: settings)
        alertService.register(type: .signal(lower: -90, upper: -40), ruuviTag: sensor)
        let sut = MigrationManagerSignalVisibility(
            ruuviStorage: storage,
            ruuviAlertService: alertService,
            ruuviSensorProperties: properties,
            ruuviLocalSettings: settings
        )

        sut.migrateIfNeeded()
        waitUntil {
            properties.updateDisplaySettingsCalls.count == 1 &&
                settings.signalVisibilityMigrationInProgress == false &&
                UserDefaults.standard.bool(forKey: "MigrationManagerSignalVisibility.didMigrate")
        }

        XCTAssertEqual(properties.updateDisplaySettingsCalls.first?.sensor.id, sensor.id)
        XCTAssertEqual(properties.updateDisplaySettingsCalls.first?.defaultDisplayOrder, false)
        XCTAssertTrue(properties.updateDisplaySettingsCalls.first?.displayOrder?.contains("SIGNAL_DBM") == true)
    }

    func testSignalVisibilityMigrationCoversEmptyStorageAndStorageFailureBranches() {
        let emptySettings = makeMigrationSettings()
        let emptyStorageSut = MigrationManagerSignalVisibility(
            ruuviStorage: StorageSpy(),
            ruuviAlertService: makeMigrationAlertService(settings: emptySettings),
            ruuviSensorProperties: SensorPropertiesSpy(),
            ruuviLocalSettings: emptySettings
        )

        emptyStorageSut.migrateIfNeeded()
        waitUntil {
            emptySettings.signalVisibilityMigrationInProgress == false
        }

        XCTAssertFalse(UserDefaults.standard.bool(forKey: "MigrationManagerSignalVisibility.didMigrate"))

        resetMigrationUserDefaults()
        let failingSettings = makeMigrationSettings()
        let failingStorage = StorageSpy()
        failingStorage.readAllError = MigrationTestError.injected
        let failingStorageSut = MigrationManagerSignalVisibility(
            ruuviStorage: failingStorage,
            ruuviAlertService: makeMigrationAlertService(settings: failingSettings),
            ruuviSensorProperties: SensorPropertiesSpy(),
            ruuviLocalSettings: failingSettings
        )

        failingStorageSut.migrateIfNeeded()
        waitUntil {
            failingSettings.signalVisibilityMigrationInProgress == false
        }

        XCTAssertFalse(UserDefaults.standard.bool(forKey: "MigrationManagerSignalVisibility.didMigrate"))
    }

    func testSignalVisibilityMigrationSkipsWhenAlreadyInProgressNonOwnerOrAlertDisabled() {
        let inProgressSettings = makeMigrationSettings()
        inProgressSettings.signalVisibilityMigrationInProgress = true
        let inProgressProperties = SensorPropertiesSpy()
        let inProgressSut = MigrationManagerSignalVisibility(
            ruuviStorage: StorageSpy(),
            ruuviAlertService: makeMigrationAlertService(settings: inProgressSettings),
            ruuviSensorProperties: inProgressProperties,
            ruuviLocalSettings: inProgressSettings
        )

        inProgressSut.migrateIfNeeded()

        XCTAssertTrue(inProgressSettings.signalVisibilityMigrationInProgress)
        XCTAssertTrue(inProgressProperties.updateDisplaySettingsCalls.isEmpty)

        resetMigrationUserDefaults()
        let nonOwnerSettings = makeMigrationSettings()
        let nonOwnerSensor = makeMigrationSensor(isOwner: false)
        let nonOwnerStorage = StorageSpy()
        nonOwnerStorage.readAllResult = [nonOwnerSensor.any]
        let nonOwnerProperties = SensorPropertiesSpy()
        let nonOwnerSut = MigrationManagerSignalVisibility(
            ruuviStorage: nonOwnerStorage,
            ruuviAlertService: makeMigrationAlertService(settings: nonOwnerSettings),
            ruuviSensorProperties: nonOwnerProperties,
            ruuviLocalSettings: nonOwnerSettings
        )

        nonOwnerSut.migrateIfNeeded()
        waitUntil {
            UserDefaults.standard.bool(forKey: "MigrationManagerSignalVisibility.didMigrate")
        }

        XCTAssertTrue(nonOwnerProperties.updateDisplaySettingsCalls.isEmpty)

        resetMigrationUserDefaults()
        let alertDisabledSettings = makeMigrationSettings()
        let alertDisabledSensor = makeMigrationSensor(isOwner: true)
        let alertDisabledStorage = StorageSpy()
        alertDisabledStorage.readAllResult = [alertDisabledSensor.any]
        let alertDisabledProperties = SensorPropertiesSpy()
        let alertDisabledSut = MigrationManagerSignalVisibility(
            ruuviStorage: alertDisabledStorage,
            ruuviAlertService: makeMigrationAlertService(settings: alertDisabledSettings),
            ruuviSensorProperties: alertDisabledProperties,
            ruuviLocalSettings: alertDisabledSettings
        )

        alertDisabledSut.migrateIfNeeded()
        waitUntil {
            UserDefaults.standard.bool(forKey: "MigrationManagerSignalVisibility.didMigrate")
        }

        XCTAssertTrue(alertDisabledProperties.updateDisplaySettingsCalls.isEmpty)
    }

    func testSignalVisibilityMigrationSkipsExistingSignalAndUsesAirDefaultsForVersion6Sensors() {
        let existingSettings = makeMigrationSettings()
        let existingSensor = makeMigrationSensor(isOwner: true)
        let existingStorage = StorageSpy()
        existingStorage.readAllResult = [existingSensor.any]
        existingStorage.sensorSettingsByID[existingSensor.id] = SensorSettingsStruct(
            luid: existingSensor.luid,
            macId: existingSensor.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            displayOrder: ["SIGNAL_DBM"]
        )
        let existingProperties = SensorPropertiesSpy()
        let existingAlertService = makeMigrationAlertService(settings: existingSettings)
        existingAlertService.register(type: .signal(lower: -90, upper: -40), ruuviTag: existingSensor)
        let existingSut = MigrationManagerSignalVisibility(
            ruuviStorage: existingStorage,
            ruuviAlertService: existingAlertService,
            ruuviSensorProperties: existingProperties,
            ruuviLocalSettings: existingSettings
        )

        existingSut.migrateIfNeeded()
        waitUntil {
            UserDefaults.standard.bool(forKey: "MigrationManagerSignalVisibility.didMigrate")
        }

        XCTAssertTrue(existingProperties.updateDisplaySettingsCalls.isEmpty)

        resetMigrationUserDefaults()
        let airSettings = makeMigrationSettings()
        let airSensor = makeMigrationSensor(version: 6, isOwner: true)
        let airStorage = StorageSpy()
        airStorage.readAllResult = [airSensor.any]
        let airProperties = SensorPropertiesSpy()
        let airAlertService = makeMigrationAlertService(settings: airSettings)
        airAlertService.register(type: .signal(lower: -90, upper: -40), ruuviTag: airSensor)
        let airSut = MigrationManagerSignalVisibility(
            ruuviStorage: airStorage,
            ruuviAlertService: airAlertService,
            ruuviSensorProperties: airProperties,
            ruuviLocalSettings: airSettings
        )

        airSut.migrateIfNeeded()
        waitUntil {
            airProperties.updateDisplaySettingsCalls.count == 1 &&
                UserDefaults.standard.bool(forKey: "MigrationManagerSignalVisibility.didMigrate")
        }

        let displayOrder = airProperties.updateDisplaySettingsCalls.first?.displayOrder ?? []
        XCTAssertTrue(displayOrder.contains("AQI_INDEX"))
        XCTAssertTrue(displayOrder.contains("CO2_PPM"))
        XCTAssertTrue(displayOrder.contains("PM25_MGM3"))
        XCTAssertTrue(displayOrder.contains("VOC_INDEX"))
        XCTAssertTrue(displayOrder.contains("NOX_INDEX"))
        XCTAssertTrue(displayOrder.contains("LUMINOSITY_LX"))
        XCTAssertTrue(displayOrder.contains("SOUNDINSTANT_SPL"))
        XCTAssertTrue(displayOrder.contains("SIGNAL_DBM"))
        XCTAssertFalse(displayOrder.contains("PM10_MGM3"))
    }

    func testSignalVisibilityMigrationCompletesWhenDisplaySettingsUpdateFails() {
        let settings = makeMigrationSettings()
        let sensor = makeMigrationSensor(isOwner: true)
        let storage = StorageSpy()
        storage.readAllResult = [sensor.any]
        let properties = SensorPropertiesSpy()
        properties.updateDisplaySettingsError = MigrationTestError.injected
        let alertService = makeMigrationAlertService(settings: settings)
        alertService.register(type: .signal(lower: -90, upper: -40), ruuviTag: sensor)
        let sut = MigrationManagerSignalVisibility(
            ruuviStorage: storage,
            ruuviAlertService: alertService,
            ruuviSensorProperties: properties,
            ruuviLocalSettings: settings
        )

        sut.migrateIfNeeded()
        waitUntil {
            properties.updateDisplaySettingsCalls.count == 1 &&
                UserDefaults.standard.bool(forKey: "MigrationManagerSignalVisibility.didMigrate")
        }

        XCTAssertFalse(settings.signalVisibilityMigrationInProgress)
    }

    func testSignalVisibilityMigrationClearsInProgressWhenAlreadyMigrated() {
        let settings = makeMigrationSettings()
        settings.signalVisibilityMigrationInProgress = true
        UserDefaults.standard.set(true, forKey: "MigrationManagerSignalVisibility.didMigrate")
        let sut = MigrationManagerSignalVisibility(
            ruuviStorage: StorageSpy(),
            ruuviAlertService: makeMigrationAlertService(settings: settings),
            ruuviSensorProperties: SensorPropertiesSpy(),
            ruuviLocalSettings: settings
        )

        sut.migrateIfNeeded()

        XCTAssertFalse(settings.signalVisibilityMigrationInProgress)
    }

    func testToRHMigrationRegistersRelativeHumidityAlertsAndCopiesDescription() {
        let settings = makeMigrationSettings()
        let sensor = makeMigrationSensor()
        let storage = StorageSpy()
        storage.readAllResult = [sensor.any]
        storage.latestRecordsByID[sensor.id] = makeMigrationRecord(
            luid: sensor.luid?.value,
            macId: sensor.macId?.value,
            temperature: 20
        )
        let alertService = makeMigrationAlertService(settings: settings)
        let lower = Humidity(value: 5, unit: .absolute)
        let upper = Humidity(value: 10, unit: .absolute)
        alertService.register(type: .humidity(lower: lower, upper: upper), ruuviTag: sensor)
        alertService.setHumidity(description: "legacy humidity", for: sensor)
        let sut = MigrationManagerToRH(
            ruuviStorage: storage,
            ruuviAlertService: alertService
        )
        let expectedLower = lower.converted(
            to: .relative(temperature: Temperature(value: 20, unit: .celsius))
        ).value
        let expectedUpper = upper.converted(
            to: .relative(temperature: Temperature(value: 20, unit: .celsius))
        ).value

        sut.migrateIfNeeded()
        waitUntil {
            alertService.lowerRelativeHumidity(for: sensor) != nil &&
                alertService.relativeHumidityDescription(for: sensor) == "legacy humidity" &&
                UserDefaults.standard.bool(forKey: "MigrationManagerToRH.migrated")
        }

        XCTAssertEqual(alertService.lowerRelativeHumidity(for: sensor) ?? 0, expectedLower, accuracy: 0.0001)
        XCTAssertEqual(alertService.upperRelativeHumidity(for: sensor) ?? 0, expectedUpper, accuracy: 0.0001)
        XCTAssertEqual(alertService.relativeHumidityDescription(for: sensor), "legacy humidity")
    }

    func testToRHMigrationSkipsWhenAlreadyMigrated() {
        UserDefaults.standard.set(true, forKey: "MigrationManagerToRH.migrated")
        let storage = StorageSpy()
        let sut = MigrationManagerToRH(
            ruuviStorage: storage,
            ruuviAlertService: makeMigrationAlertService(settings: makeMigrationSettings())
        )

        sut.migrateIfNeeded()

        XCTAssertEqual(storage.readAllCallCount, 0)
    }

    func testToRHMigrationHandlesStorageFailureAsEmptyMigration() {
        let storage = StorageSpy()
        storage.readAllError = MigrationTestError.injected
        let sut = MigrationManagerToRH(
            ruuviStorage: storage,
            ruuviAlertService: makeMigrationAlertService(settings: makeMigrationSettings())
        )

        sut.migrateIfNeeded()
        waitUntil {
            storage.readAllCallCount == 1
        }

        XCTAssertTrue(UserDefaults.standard.bool(forKey: "MigrationManagerToRH.migrated"))
    }

    func testFixRHAlertsScalesLegacyPercentValuesIntoFractions() {
        let settings = makeMigrationSettings()
        let sensor = makeMigrationSensor()
        let storage = StorageSpy()
        storage.readAllResult = [sensor.any]
        let alertService = makeMigrationAlertService(settings: settings)
        alertService.register(type: .relativeHumidity(lower: 50, upper: 80), ruuviTag: sensor)
        let sut = RuuviMigrationFixRHAlerts(
            ruuviStorage: storage,
            ruuviAlertService: alertService
        )

        sut.migrateIfNeeded()
        waitUntil {
            (alertService.lowerRelativeHumidity(for: sensor) ?? 0) < 1 &&
                UserDefaults.standard.bool(forKey: "RuuviMigrationFixRHAlerts.migrated")
        }

        XCTAssertEqual(alertService.lowerRelativeHumidity(for: sensor) ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(alertService.upperRelativeHumidity(for: sensor) ?? 0, 0.8, accuracy: 0.0001)
    }

    func testSensorSettingsMigrationSkipsMissingIdentifiersAndPreservesLegacyOffsetWhenUpdateFails() {
        let sensorWithoutLuid = makeMigrationSensor(luid: nil)
        let storageWithoutLuid = StorageSpy()
        storageWithoutLuid.readAllResult = [sensorWithoutLuid.any]
        let calibrationWithoutLuid = CalibrationPersistenceSpy()
        let offsetWithoutLuid = OffsetCalibrationSpy()
        let missingIdentifierSut = MigrationManagerSensorSettings(
            calibrationPersistence: calibrationWithoutLuid,
            ruuviStorage: storageWithoutLuid,
            ruuviOffsetCalibrationService: offsetWithoutLuid
        )

        missingIdentifierSut.migrateIfNeeded()
        waitUntil {
            storageWithoutLuid.readAllCallCount == 1
        }

        XCTAssertTrue(offsetWithoutLuid.calls.isEmpty)
        XCTAssertTrue(calibrationWithoutLuid.setCalls.isEmpty)

        resetMigrationUserDefaults()
        let sensor = makeMigrationSensor()
        let storage = StorageSpy()
        storage.readAllResult = [sensor.any]
        let calibration = CalibrationPersistenceSpy()
        calibration.offsets[sensor.luid!.value] = (40, Date())
        let offsetService = OffsetCalibrationSpy()
        offsetService.setError = MigrationTestError.injected
        let failingSut = MigrationManagerSensorSettings(
            calibrationPersistence: calibration,
            ruuviStorage: storage,
            ruuviOffsetCalibrationService: offsetService
        )

        failingSut.migrateIfNeeded()
        waitUntil {
            offsetService.calls.count == 1
        }

        XCTAssertTrue(calibration.setCalls.isEmpty)
    }

    func testAlertServiceMigrationMovesLegacyHumidityKeysIntoAlertService() {
        let settings = makeMigrationSettings()
        let sensorRelative = makeMigrationSensor(luid: "luid-relative", macId: "AA:BB:CC:11:22:33")
        let sensorAbsolute = makeMigrationSensor(luid: "luid-absolute", macId: "AA:BB:CC:11:22:44")
        let storage = StorageSpy()
        storage.readAllResult = [sensorRelative.any, sensorAbsolute.any]
        storage.latestRecordsByID[sensorRelative.id] = makeMigrationRecord(
            luid: sensorRelative.luid?.value,
            macId: sensorRelative.macId?.value,
            temperature: 20
        )
        let alertService = makeMigrationAlertService(settings: settings)
        let sut = MigrationManagerAlertService(
            ruuviStorage: storage,
            ruuviAlertService: alertService
        )

        let relativeLowerKey =
            "AlertPersistenceUserDefaults.relativeHumidityLowerBoundUDKeyPrefix.\(sensorRelative.id)"
        let relativeUpperKey =
            "AlertPersistenceUserDefaults.relativeHumidityUpperBoundUDKeyPrefix.\(sensorRelative.id)"
        let relativeIsOnKey =
            "AlertPersistenceUserDefaults.relativeHumidityAlertIsOnUDKeyPrefix.\(sensorRelative.id)"
        let relativeDescriptionKey =
            "AlertPersistenceUserDefaults.relativeHumidityAlertDescriptionUDKeyPrefix.\(sensorRelative.id)"
        let absoluteLowerKey =
            "AlertPersistenceUserDefaults.absoluteHumidityLowerBoundUDKeyPrefix.\(sensorAbsolute.id)"
        let absoluteUpperKey =
            "AlertPersistenceUserDefaults.absoluteHumidityUpperBoundUDKeyPrefix.\(sensorAbsolute.id)"
        let absoluteIsOnKey =
            "AlertPersistenceUserDefaults.absoluteHumidityAlertIsOnUDKeyPrefix.\(sensorAbsolute.id)"
        let absoluteDescriptionKey =
            "AlertPersistenceUserDefaults.absoluteHumidityAlertDescriptionUDKeyPrefix.\(sensorAbsolute.id)"

        UserDefaults.standard.set(true, forKey: relativeIsOnKey)
        UserDefaults.standard.set(60.0, forKey: relativeLowerKey)
        UserDefaults.standard.set(80.0, forKey: relativeUpperKey)
        UserDefaults.standard.set("Relative description", forKey: relativeDescriptionKey)
        UserDefaults.standard.set(true, forKey: absoluteIsOnKey)
        UserDefaults.standard.set(5.0, forKey: absoluteLowerKey)
        UserDefaults.standard.set(9.0, forKey: absoluteUpperKey)
        UserDefaults.standard.set("Absolute description", forKey: absoluteDescriptionKey)

        sut.migrateIfNeeded()
        waitUntil {
            UserDefaults.standard.integer(forKey: "MigrationManagerAlertService.persistanceVersion") == 1
        }

        XCTAssertFalse(UserDefaults.standard.bool(forKey: relativeIsOnKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: absoluteIsOnKey))
        XCTAssertEqual(alertService.humidityDescription(for: sensorRelative), "Relative description")
        XCTAssertEqual(alertService.humidityDescription(for: sensorAbsolute), "Absolute description")

        let expectedRelativeLower = Humidity(
            value: 0.6,
            unit: .relative(temperature: Temperature(value: 20, unit: .celsius))
        ).converted(to: .absolute).value
        let expectedRelativeUpper = Humidity(
            value: 0.8,
            unit: .relative(temperature: Temperature(value: 20, unit: .celsius))
        ).converted(to: .absolute).value
        XCTAssertEqual(
            alertService.lowerHumidity(for: sensorRelative)?.converted(to: .absolute).value ?? 0,
            expectedRelativeLower,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            alertService.upperHumidity(for: sensorRelative)?.converted(to: .absolute).value ?? 0,
            expectedRelativeUpper,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            alertService.lowerHumidity(for: sensorAbsolute)?.converted(to: .absolute).value ?? 0,
            5.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            alertService.upperHumidity(for: sensorAbsolute)?.converted(to: .absolute).value ?? 0,
            9.0,
            accuracy: 0.0001
        )
    }

    func testAlertServiceMigrationCoversNoLegacyAlertAndStorageFailureBranches() {
        let noAlertSettings = makeMigrationSettings()
        let sensor = makeMigrationSensor()
        let noAlertStorage = StorageSpy()
        noAlertStorage.readAllResult = [sensor.any]
        let noAlertService = makeMigrationAlertService(settings: noAlertSettings)
        let noAlertSut = MigrationManagerAlertService(
            ruuviStorage: noAlertStorage,
            ruuviAlertService: noAlertService
        )

        noAlertSut.migrateIfNeeded()
        waitUntil {
            UserDefaults.standard.integer(forKey: "MigrationManagerAlertService.persistanceVersion") == 1
        }

        XCTAssertNil(noAlertService.humidityDescription(for: sensor))

        resetMigrationUserDefaults()
        let failingStorage = StorageSpy()
        failingStorage.readAllError = MigrationTestError.injected
        let failingSut = MigrationManagerAlertService(
            ruuviStorage: failingStorage,
            ruuviAlertService: makeMigrationAlertService(settings: makeMigrationSettings())
        )

        failingSut.migrateIfNeeded()
        waitUntil {
            UserDefaults.standard.integer(forKey: "MigrationManagerAlertService.persistanceVersion") == 1
        }

        XCTAssertEqual(failingStorage.readAllCallCount, 1)
    }

    func testIsExcludedFromBackupMigrationSetsDatabaseFileFlag() throws {
        let dbPath = makeTemporaryDatabasePath()
        FileManager.default.createFile(atPath: dbPath, contents: Data(), attributes: nil)
        var url = URL(fileURLWithPath: dbPath)
        try url.setResourceValues({
            var values = URLResourceValues()
            values.isExcludedFromBackup = false
            return values
        }())
        let sut = MigrationManagerIsExcludedFromBackup(
            sqliteContext: SQLiteContextSpy(dbPath: dbPath)
        )

        sut.migrateIfNeeded()

        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    func testIsExcludedFromBackupMigrationLeavesExistingExcludedFlagUntouched() throws {
        let dbPath = makeTemporaryDatabasePath()
        FileManager.default.createFile(atPath: dbPath, contents: Data(), attributes: nil)
        var url = URL(fileURLWithPath: dbPath)
        try url.setResourceValues({
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            return values
        }())
        let sut = MigrationManagerIsExcludedFromBackup(
            sqliteContext: SQLiteContextSpy(dbPath: dbPath)
        )

        sut.migrateIfNeeded()

        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    func testIsExcludedFromBackupMigrationSwallowsFileSystemErrors() {
        let sut = MigrationManagerIsExcludedFromBackup(
            sqliteContext: SQLiteContextSpy(dbPath: makeTemporaryDatabasePath())
        )

        sut.migrateIfNeeded()
    }

    func testIsExcludedFromBackupMigrationSwallowsUnsupportedResourcePaths() {
        let sut = MigrationManagerIsExcludedFromBackup(
            sqliteContext: SQLiteContextPathOnlySpy(dbPath: "/dev/null/ruuvi.sqlite")
        )

        sut.migrateIfNeeded()
    }
}

private func makeMigrationSettings() -> RuuviLocalSettingsUserDefaults {
    let settings = RuuviLocalSettingsUserDefaults()
    settings.temperatureUnit = .celsius
    settings.temperatureAccuracy = .two
    settings.humidityUnit = .percent
    settings.humidityAccuracy = .two
    settings.pressureUnit = .hectopascals
    settings.pressureAccuracy = .two
    settings.language = .english
    settings.signalVisibilityMigrationInProgress = false
    settings.chartDurationHours = 24
    settings.dataPruningOffsetHours = 24
    settings.connectionTimeout = 10
    settings.serviceTimeout = 20
    settings.networkPullIntervalSeconds = 30
    return settings
}

private func makeMigrationAlertService(
    settings: RuuviLocalSettingsUserDefaults
) -> RuuviServiceAlertImpl {
    RuuviServiceAlertImpl(
        cloud: NoOpCloud(),
        localIDs: RuuviLocalIDsUserDefaults(),
        ruuviLocalSettings: settings
    )
}

private func makeMigrationSensor(
    luid: String? = "luid-1",
    macId: String? = "AA:BB:CC:11:22:33",
    version: Int = 5,
    isOwner: Bool = false
) -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: version,
        firmwareVersion: "1.0.0",
        luid: luid?.luid,
        macId: macId?.mac,
        serviceUUID: nil,
        isConnectable: true,
        name: "Sensor",
        isClaimed: false,
        isOwner: isOwner,
        owner: nil,
        ownersPlan: nil,
        isCloudSensor: false,
        canShare: false,
        sharedTo: [],
        maxHistoryDays: nil
    )
}

private func makeMigrationRecord(
    luid: String? = "luid-1",
    macId: String? = "AA:BB:CC:11:22:33",
    temperature: Double? = nil,
    humidity: Double? = nil,
    date: Date = Date()
) -> RuuviTagSensorRecord {
    RuuviTagSensorRecordStruct(
        luid: luid?.luid,
        date: date,
        source: .advertisement,
        macId: macId?.mac,
        rssi: -60,
        version: 5,
        temperature: temperature.map { Temperature(value: $0, unit: .celsius) },
        humidity: humidity.map {
            Humidity(
                value: $0,
                unit: .relative(
                    temperature: Temperature(value: temperature ?? 20, unit: .celsius)
                )
            )
        },
        pressure: nil,
        acceleration: nil,
        voltage: nil,
        movementCounter: nil,
        measurementSequenceNumber: nil,
        txPower: nil,
        pm1: nil,
        pm25: nil,
        pm4: nil,
        pm10: nil,
        co2: nil,
        voc: nil,
        nox: nil,
        luminance: nil,
        dbaInstant: nil,
        dbaAvg: nil,
        dbaPeak: nil,
        temperatureOffset: 0,
        humidityOffset: 0,
        pressureOffset: 0
    )
}

private func makeTemporaryDatabasePath() -> String {
    URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("sqlite")
        .path
}

private func resetMigrationUserDefaults() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys {
        UserDefaults.standard.removeObject(forKey: key)
    }
    if let appGroup = UserDefaults(suiteName: "group.com.ruuvi.station.pnservice") {
        for key in appGroup.dictionaryRepresentation().keys {
            appGroup.removeObject(forKey: key)
        }
    }
}

private func waitUntil(
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line,
    condition: @escaping () -> Bool
) {
    let timeoutDate = Date().addingTimeInterval(timeout)
    while Date() < timeoutDate {
        if condition() {
            return
        }
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
    XCTFail("Condition not met within \(timeout) seconds", file: file, line: line)
}

private enum MigrationTestError: Error {
    case injected
}

private final class StorageSpy: RuuviStorage {
    var readAllResult: [AnyRuuviTagSensor] = []
    var latestRecordsByID: [String: RuuviTagSensorRecord] = [:]
    var sensorSettingsByID: [String: SensorSettings] = [:]
    var readAllError: Error?
    var readAllCallCount = 0

    func read(_ id: String, after date: Date, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        []
    }

    func readDownsampled(
        _ id: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws -> [RuuviTagSensorRecord] {
        []
    }

    func readOne(_ id: String) async throws -> AnyRuuviTagSensor {
        try XCTUnwrap(readAllResult.first { $0.id == id })
    }

    func readAll(_ id: String) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ id: String, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ id: String, after date: Date) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll() async throws -> [AnyRuuviTagSensor] {
        readAllCallCount += 1
        if let readAllError {
            throw readAllError
        }
        return readAllResult
    }
    func readLast(_ id: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { latestRecordsByID[ruuviTag.id] }
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { latestRecordsByID[ruuviTag.id] }
    func getStoredTagsCount() async throws -> Int { readAllResult.count }
    func getClaimedTagsCount() async throws -> Int { 0 }
    func getOfflineTagsCount() async throws -> Int { 0 }
    func getStoredMeasurementsCount() async throws -> Int { 0 }
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        sensorSettingsByID[ruuviTag.id]
    }
    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for key: String) async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for type: RuuviCloudQueuedRequestType) async throws -> [RuuviCloudQueuedRequest] { [] }
}

private final class CalibrationPersistenceSpy: CalibrationPersistence {
    var offsets: [String: (Double, Date?)] = [:]
    var setCalls: [(Identifier, Double, Date?)] = []

    func humidityOffset(for identifier: Identifier) -> (Double, Date?) {
        offsets[identifier.value] ?? (0, nil)
    }

    func setHumidity(date: Date?, offset: Double, for identifier: Identifier) {
        offsets[identifier.value] = (offset, date)
        setCalls.append((identifier, offset, date))
    }
}

private final class OffsetCalibrationSpy: RuuviServiceOffsetCalibration {
    struct Call {
        let sensor: RuuviTagSensor
        let type: OffsetCorrectionType
        let offset: Double?
    }

    var calls: [Call] = []
    var setError: Error?

    func set(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        calls.append(Call(sensor: sensor, type: type, offset: offset))
        if let setError {
            throw setError
        }
        return SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: nil,
            humidityOffset: offset,
            pressureOffset: nil
        )
    }
}

private final class SensorPropertiesSpy: RuuviServiceSensorProperties {
    struct UpdateDisplaySettingsCall {
        let sensor: RuuviTagSensor
        let displayOrder: [String]?
        let defaultDisplayOrder: Bool
    }

    var updateDisplaySettingsCalls: [UpdateDisplaySettingsCall] = []
    var updateDisplaySettingsError: Error?

    func set(name: String, for sensor: RuuviTagSensor) async throws -> AnyRuuviTagSensor { sensor.any }
    func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) async throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("image")
    }
    func setNextDefaultBackground(for sensor: RuuviTagSensor) async throws -> UIImage { UIImage() }
    func getImage(for sensor: RuuviTagSensor) async throws -> UIImage { UIImage() }
    func removeImage(for sensor: RuuviTagSensor) {}

    func updateDisplaySettings(
        for sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool
    ) async throws -> SensorSettings {
        updateDisplaySettingsCalls.append(
            UpdateDisplaySettingsCall(
                sensor: sensor,
                displayOrder: displayOrder,
                defaultDisplayOrder: defaultDisplayOrder
            )
        )
        if let updateDisplaySettingsError {
            throw updateDisplaySettingsError
        }
        return SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            displayOrder: displayOrder,
            defaultDisplayOrder: defaultDisplayOrder
        )
    }

    func updateDescription(
        for sensor: RuuviTagSensor,
        description: String?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            description: description
        )
    }
}

private final class PoolSpy: RuuviPool {
    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func create(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func deleteLast(_ ruuviTagId: String) async throws -> Bool { true }
    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool { true }
    func cleanupDBSpace() async throws -> Bool { true }
    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }
    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            displayOrder: displayOrder,
            defaultDisplayOrder: defaultDisplayOrder
        )
    }
    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            description: description
        )
    }
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? { nil }
    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool { true }
    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool { true }
    func deleteQueuedRequests() async throws -> Bool { true }
    func save(subscription: CloudSensorSubscription) async throws -> CloudSensorSubscription { subscription }
    func readSensorSubscriptionSettings(_ ruuviTag: RuuviTagSensor) async throws -> CloudSensorSubscription? { nil }
}

private final class SQLiteContextSpy: SQLiteContext {
    let database: GRDBDatabase

    init(dbPath: String) {
        database = GRDBDatabaseSpy(dbPath: dbPath)
    }
}

private final class SQLiteContextPathOnlySpy: SQLiteContext {
    let database: GRDBDatabase

    init(dbPath: String) {
        database = GRDBDatabasePathOnlySpy(dbPath: dbPath)
    }
}

private final class GRDBDatabaseSpy: GRDBDatabase {
    let dbPool: DatabasePool
    let dbPath: String

    init(dbPath: String) {
        self.dbPath = dbPath
        dbPool = try! DatabasePool(path: dbPath)
    }

    func migrateIfNeeded() {}
}

private final class GRDBDatabasePathOnlySpy: GRDBDatabase {
    let dbPool: DatabasePool
    let dbPath: String

    init(dbPath: String) {
        self.dbPath = dbPath
        dbPool = try! DatabasePool(path: makeTemporaryDatabasePath())
    }

    func migrateIfNeeded() {}
}

private final class NoOpCloud: RuuviCloud {
    func requestCode(email: String) async throws -> String? { nil }
    func validateCode(code: String) async throws -> ValidateCodeResponse {
        ValidateCodeResponse(email: "", apiKey: "")
    }
    func deleteAccount(email: String) async throws -> Bool { true }
    func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int { 0 }
    func unregisterPNToken(token: String?, tokenId: Int?) async throws -> Bool { true }
    func listPNTokens() async throws -> [RuuviCloudPNToken] { [] }
    func loadSensors() async throws -> [AnyCloudSensor] { [] }
    func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) async throws -> [RuuviCloudSensorDense] { [] }
    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws -> [AnyRuuviTagSensorRecord] { [] }
    func claim(name: String, macId: MACIdentifier) async throws -> MACIdentifier? { nil }
    func contest(macId: MACIdentifier, secret: String) async throws -> MACIdentifier? { nil }
    func unclaim(macId: MACIdentifier, removeCloudHistory: Bool) async throws -> MACIdentifier { macId }
    func share(macId: MACIdentifier, with email: String) async throws -> ShareSensorResponse {
        ShareSensorResponse()
    }
    func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier { macId }
    func loadShared(for sensor: RuuviTagSensor) async throws -> Set<AnyShareableSensor> { [] }
    func checkOwner(macId: MACIdentifier) async throws -> (String?, String?) { (nil, nil) }
    func update(name: String, for sensor: RuuviTagSensor) async throws -> AnyRuuviTagSensor { sensor.any }
    func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("noop")
    }
    func resetImage(for macId: MACIdentifier) async throws {}
    func getCloudSettings() async throws -> RuuviCloudSettings? { nil }
    func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit { temperatureUnit }
    func set(temperatureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        temperatureAccuracy
    }
    func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit { humidityUnit }
    func set(humidityAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        humidityAccuracy
    }
    func set(pressureUnit: UnitPressure) async throws -> UnitPressure { pressureUnit }
    func set(pressureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        pressureAccuracy
    }
    func set(showAllData: Bool) async throws -> Bool { showAllData }
    func set(drawDots: Bool) async throws -> Bool { drawDots }
    func set(chartDuration: Int) async throws -> Int { chartDuration }
    func set(showMinMaxAvg: Bool) async throws -> Bool { showMinMaxAvg }
    func set(cloudMode: Bool) async throws -> Bool { cloudMode }
    func set(dashboard: Bool) async throws -> Bool { dashboard }
    func set(dashboardType: DashboardType) async throws -> DashboardType { dashboardType }
    func set(dashboardTapActionType: DashboardTapActionType) async throws -> DashboardTapActionType {
        dashboardTapActionType
    }
    func set(disableEmailAlert: Bool) async throws -> Bool { disableEmailAlert }
    func set(disablePushAlert: Bool) async throws -> Bool { disablePushAlert }
    func set(marketingPreference: Bool) async throws -> Bool { marketingPreference }
    func set(profileLanguageCode: String) async throws -> String { profileLanguageCode }
    func set(dashboardSensorOrder: [String]) async throws -> [String] { dashboardSensorOrder }
    func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws -> AnyRuuviTagSensor { sensor.any }
    func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor { sensor.any }
    func setAlert(
        type: RuuviCloudAlertType,
        settingType: RuuviCloudAlertSettingType,
        isEnabled: Bool,
        min: Double?,
        max: Double?,
        counter: Int?,
        delay: Int?,
        description: String?,
        for macId: MACIdentifier
    ) async throws {}
    func loadAlerts() async throws -> [RuuviCloudSensorAlerts] { [] }
    func executeQueuedRequest(from request: RuuviCloudQueuedRequest) async throws -> Bool { true }
}
