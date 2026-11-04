import Foundation
import UIKit
import XCTest
import RuuviContext
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviService
import RuuviStorage
@testable import RuuviMigration
#if SWIFT_PACKAGE
    import RuuviContextSQLite
    import RuuviLocalUserDefaults
    import RuuviPersistenceSQLite
    import RuuviPoolCoordinator
    import RuuviServiceAlert
    import RuuviStorageCoordinator
    @testable import RuuviMigrationImpl
#endif

@MainActor final class MigrationFixture {
    let suite = UUID().uuidString
    let defaults: UserDefaults
    let directory: URL
    let context: SQLiteContext
    let persistence: RuuviPersistenceSQLite
    let storage: MigrationStorage
    let ids: RuuviLocalIDs
    var settings: RuuviLocalSettings
    let alerts: RuuviServiceAlertImpl
    let properties: MigrationProperties
    let pool: RuuviPool
    var sensors = [RuuviTagSensorStruct]()
    private let restoreSettings: () -> Void

    init() throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("migration.sqlite"))
        persistence = RuuviPersistenceSQLite(context: context)
        storage = MigrationStorage(RuuviStorageFactoryCoordinator().create(sqlite: persistence))
        let local = RuuviLocalFactoryUserDefaults()
        ids = local.createLocalIDs()
        settings = local.createLocalSettings()
        var savedSettings = settings
        let saved = (
            settings.dataPruningOffsetHours, settings.chartDurationHours,
            settings.networkPullIntervalSeconds, settings.connectionTimeout, settings.serviceTimeout,
            settings.signalVisibilityMigrationInProgress
        )
        restoreSettings = {
            savedSettings.dataPruningOffsetHours = saved.0
            savedSettings.chartDurationHours = saved.1
            savedSettings.networkPullIntervalSeconds = saved.2
            savedSettings.connectionTimeout = saved.3
            savedSettings.serviceTimeout = saved.4
            savedSettings.signalVisibilityMigrationInProgress = saved.5
        }
        alerts = RuuviServiceAlertImpl(cloud: MigrationCloudStub(), localIDs: ids, ruuviLocalSettings: settings)
        properties = MigrationProperties(persistence: persistence)
        pool = RuuviPoolFactoryCoordinator().create(
            sqlite: persistence, idPersistence: ids, settings: settings,
            connectionPersistence: local.createLocalConnections())
    }

    func sensor(version: Int = 5, owner: Bool = true, record: Bool = true) async throws -> RuuviTagSensorStruct {
        let bytes = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        let mac = stride(from: 0, to: 12, by: 2).map { offset in
            let start = bytes.index(bytes.startIndex, offsetBy: offset)
            return String(bytes[start..<bytes.index(start, offsetBy: 2)])
        }.joined(separator: ":").mac
        let sensor = RuuviTagSensorStruct(
            version: version, firmwareVersion: nil, luid: UUID().uuidString.luid, macId: mac,
            serviceUUID: nil, isConnectable: true, name: "Migration sensor", isClaimed: false,
            isOwner: owner, owner: nil, ownersPlan: nil, isCloudSensor: false, canShare: false,
            sharedTo: [], maxHistoryDays: nil)
        ids.set(luid: sensor.luid!, for: mac)
        ids.set(mac: mac, for: sensor.luid!)
        sensors.append(sensor)
        _ = try await persistence.create(sensor)
        if record { try await addRecord(sensor) }
        return sensor
    }

    func addRecord(_ sensor: RuuviTagSensor, latest: Bool = false) async throws {
        let record = RuuviTagSensorRecordStruct(
            luid: sensor.luid, date: Date(), source: .advertisement, macId: sensor.macId, rssi: -50,
            version: sensor.version, temperature: .init(value: 20, unit: .celsius), humidity: nil,
            pressure: nil, acceleration: nil, voltage: nil, movementCounter: nil,
            measurementSequenceNumber: nil, txPower: nil, pm1: nil, pm25: nil, pm4: nil, pm10: nil,
            co2: nil, voc: nil, nox: nil, luminance: nil, dbaInstant: nil, dbaAvg: nil, dbaPeak: nil,
            temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0)
        _ = try await persistence.create(record)
        if latest { _ = try await persistence.createLast(record) }
    }

    func legacy(_ kind: String, _ field: String, sensor: RuuviTagSensor) -> String {
        "AlertPersistenceUserDefaults.\(kind)Humidity\(field)UDKeyPrefix.\(sensor.id)"
    }

    func enableLegacy(_ kind: String, sensor: RuuviTagSensor, lower: Double, upper: Double) {
        defaults.set(true, forKey: legacy(kind, "AlertIsOn", sensor: sensor))
        defaults.set(lower, forKey: legacy(kind, "LowerBound", sensor: sensor))
        defaults.set(upper, forKey: legacy(kind, "UpperBound", sensor: sensor))
    }

    var alertMigration: MigrationManagerAlertService {
        MigrationManagerAlertService(ruuviStorage: storage, ruuviAlertService: alerts, defaults: defaults)
    }
    var humidityMigration: MigrationManagerToRH {
        MigrationManagerToRH(ruuviStorage: storage, ruuviAlertService: alerts, defaults: defaults)
    }
    var boundsMigration: RuuviMigrationFixRHAlerts {
        RuuviMigrationFixRHAlerts(ruuviStorage: storage, ruuviAlertService: alerts, defaults: defaults)
    }
    var visibilityMigration: MigrationManagerSignalVisibility {
        MigrationManagerSignalVisibility(
            ruuviStorage: storage, ruuviAlertService: alerts, ruuviSensorProperties: properties,
            ruuviLocalSettings: settings, defaults: defaults)
    }

    func close() {
        for sensor in sensors { for type in AlertType.allCases { alerts.remove(type: type, ruuviTag: sensor) } }
        restoreSettings()
        defaults.removePersistentDomain(forName: suite)
        try? persistence.database.dbPool.close()
        try? FileManager.default.removeItem(at: directory)
    }
}

final class MigrationProperties: RuuviServiceSensorProperties {
    let persistence: RuuviPersistence
    var writes = [(String, [String]?, Bool)]()
    var failWrite = false
    var beforeWrite: (() async -> Void)?
    init(persistence: RuuviPersistence) { self.persistence = persistence }
    func updateDisplaySettings(for sensor: RuuviTagSensor, displayOrder: [String]?, defaultDisplayOrder: Bool)
        async throws(RuuviServiceError) -> SensorSettings
    {
        await beforeWrite?()
        if failWrite { throw .macIdIsNil }
        do {
            let result = try await persistence.updateDisplaySettings(
                for: sensor, displayOrder: displayOrder, defaultDisplayOrder: defaultDisplayOrder,
                displayOrderLastUpdated: nil, defaultDisplayOrderLastUpdated: nil)
            writes.append((sensor.id, displayOrder, defaultDisplayOrder))
            return result
        } catch { throw .macIdIsNil }
    }
    func set(name: String, for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> AnyRuuviTagSensor {
        XCTFail("Unexpected name change"); throw .macIdIsNil
    }
    func set(
        image: UIImage, for sensor: RuuviTagSensor, progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize, compressionQuality: CGFloat
    ) async throws(RuuviServiceError) -> URL {
        XCTFail("Unexpected image change"); throw .macIdIsNil
    }
    func setNextDefaultBackground(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> UIImage {
        XCTFail("Unexpected background change"); throw .macIdIsNil
    }
    func getImage(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> UIImage {
        XCTFail("Unexpected image read"); throw .macIdIsNil
    }
    func removeImage(for sensor: RuuviTagSensor) { XCTFail("Unexpected image removal") }
    func updateDescription(for sensor: RuuviTagSensor, description: String?) async throws(RuuviServiceError)
        -> SensorSettings
    {
        XCTFail("Unexpected description change"); throw .macIdIsNil
    }
}
