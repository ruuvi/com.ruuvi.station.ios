import Foundation
import XCTest
import RuuviContext
import RuuviOntology
import RuuviPersistence
import RuuviStorage
import RuuviService
@testable import RuuviMigration
#if SWIFT_PACKAGE
    import RuuviContextSQLite
    import RuuviPersistenceSQLite
    import RuuviStorageCoordinator
    @testable import RuuviMigrationImpl
#endif

final class RuuviMigrationTests: XCTestCase {
    @MainActor func testCalibrationMigrationRetainsLegacyValuesOnFailureAndRetriesSafely() async throws {
        let fixture = try CalibrationMigrationFixture()
        defer { fixture.close() }
        for sensor in fixture.sensors { _ = try await fixture.persistence.create(sensor) }
        fixture.calibration.values = Dictionary(
            uniqueKeysWithValues: fixture.sensors.compactMap {
                $0.luid.map { ($0.value, (10.0, Date(timeIntervalSince1970: 1000))) }
            })
        fixture.offsets.failOnCall = 2
        do {
            try await fixture.migration.migrate()
            XCTFail("A failed write must leave the migration incomplete")
        } catch {
            guard let failure = error as? RuuviServiceError, case .macIdIsNil = failure else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertFalse(fixture.completed)
        XCTAssertTrue(fixture.calibration.values.values.allSatisfy { $0.0 == 10 && $0.1 != nil })
        fixture.offsets.failOnCall = nil
        try await fixture.migration.migrate()
        XCTAssertTrue(fixture.completed)
        XCTAssertTrue(fixture.calibration.values.values.allSatisfy { $0.0 == 0 && $0.1 == nil })
        XCTAssertEqual(fixture.offsets.offsets, [0.1, 0.1, 0.1, 0.1])
        try await fixture.migration.migrate()
        XCTAssertEqual(fixture.offsets.offsets.count, 4, "A completed migration must be idempotent")
    }

    @MainActor func testNoLegacyCalibrationDoesNotOverwriteExistingSettings() async throws {
        let fixture = try CalibrationMigrationFixture()
        defer { fixture.close() }
        for sensor in fixture.sensors { _ = try await fixture.persistence.create(sensor) }
        try await fixture.migration.migrate()
        XCTAssertTrue(fixture.completed)
        XCTAssertTrue(fixture.offsets.offsets.isEmpty)
    }

    @MainActor func testCancelledMigrationDoesNotClearLegacyCalibration() async throws {
        let fixture = try CalibrationMigrationFixture()
        defer { fixture.close() }
        for sensor in fixture.sensors { _ = try await fixture.persistence.create(sensor) }
        let task = Task { @MainActor in try await fixture.migration.migrate() }
        task.cancel()
        do { try await task.value; XCTFail("Cancelled migration unexpectedly completed") } catch {}
        XCTAssertFalse(fixture.completed)
        XCTAssertTrue(fixture.offsets.offsets.isEmpty)
    }
}

@MainActor private final class CalibrationMigrationFixture {
    let directory: URL
    let defaults: UserDefaults
    let suite = UUID().uuidString
    let persistence: RuuviPersistenceSQLite
    let storage: RuuviStorage
    let calibration = CalibrationMemory()
    let offsets = CalibrationOffsetSpy()
    let sensors = (1...2).map { index in
        RuuviTagSensorStruct(
            version: 5, firmwareVersion: nil, luid: UUID().uuidString.luid,
            macId: "AA:BB:CC:DD:EE:0\(index)".mac, serviceUUID: nil, isConnectable: false,
            name: "Sensor \(index)", isClaimed: false, isOwner: false, owner: nil, ownersPlan: nil,
            isCloudSensor: false, canShare: false, sharedTo: [], maxHistoryDays: nil)
    }
    lazy var migration = MigrationManagerSensorSettings(
        calibrationPersistence: calibration, ruuviStorage: storage,
        ruuviOffsetCalibrationService: offsets, defaults: defaults)
    var completed: Bool { defaults.bool(forKey: "MigrationManagerSensorSettings.didMigrateSensorSettings") }
    init() throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("migration.sqlite"))
        persistence = RuuviPersistenceSQLite(context: context)
        storage = RuuviStorageFactoryCoordinator().create(sqlite: persistence)
    }
    func close() {
        defaults.removePersistentDomain(forName: suite)
        try? persistence.database.dbPool.close()
        try? FileManager.default.removeItem(at: directory)
    }
}

private final class CalibrationMemory: CalibrationPersistence {
    var values = [String: (Double, Date?)]()
    func humidityOffset(for identifier: Identifier) -> (Double, Date?) { values[identifier.value] ?? (0, nil) }
    func setHumidity(date: Date?, offset: Double, for identifier: Identifier) {
        values[identifier.value] = (offset, date)
    }
}

private final class CalibrationOffsetSpy: RuuviServiceOffsetCalibration {
    var offsets = [Double]()
    var failOnCall: Int?
    func set(
        offset: Double?, of type: OffsetCorrectionType, for sensor: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws(RuuviServiceError) -> SensorSettings {
        offsets.append(offset ?? 0)
        if offsets.count == failOnCall { throw .macIdIsNil }
        return SensorSettingsStruct(
            luid: sensor.luid, macId: sensor.macId, temperatureOffset: nil, humidityOffset: offset, pressureOffset: nil)
    }
}
