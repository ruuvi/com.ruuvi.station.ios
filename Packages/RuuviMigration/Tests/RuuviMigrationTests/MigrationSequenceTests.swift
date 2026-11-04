import Foundation
import XCTest
import RuuviOntology
import RuuviService
@testable import RuuviMigration
#if SWIFT_PACKAGE
    @testable import RuuviMigrationImpl
#endif

@MainActor final class MigrationSequenceTests: XCTestCase {
    func testRunnerAwaitsPersistenceBeforeStartingDependentMigration() async throws {
        var events = [String]()
        let started = expectation(description: "First migration entered")
        let gate = MigrationGate()
        let first = BlockMigration {
            events.append("first started")
            started.fulfill()
            await gate.wait()
            events.append("first persisted")
        }
        let second = BlockMigration { events.append("second started") }
        let task = Task { @MainActor in try await RuuviMigrationRunner.migrate([first, second]) }
        await fulfillment(of: [started], timeout: 5)
        XCTAssertEqual(events, ["first started"])
        gate.open()
        try await task.value
        XCTAssertEqual(events, ["first started", "first persisted", "second started"])
    }

    func testFailedOrCancelledMigrationDoesNotStartDependentWork() async throws {
        var ran = false
        let dependent = BlockMigration { ran = true }
        do {
            try await RuuviMigrationRunner.migrate([BlockMigration { throw RuuviServiceError.macIdIsNil }, dependent])
            XCTFail("Expected failure")
        } catch is RuuviServiceError {}
        XCTAssertFalse(ran)
        let task = Task { @MainActor in try await RuuviMigrationRunner.migrate([dependent]) }
        task.cancel()
        do { try await task.value; XCTFail("Expected cancellation") } catch is CancellationError {}
        XCTAssertFalse(ran)
    }

    func testSimpleMigrationsSetNewDefaultsOnceAndPreserveSubsequentEdits() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let migrations: [RuuviMigration] = [
            MigrationManagerToPrune240(settings: fixture.settings, defaults: fixture.defaults),
            MigrationManagerToChartDuration240(settings: fixture.settings, defaults: fixture.defaults),
            MigrationManagerToNetworkPull60(settings: fixture.settings, defaults: fixture.defaults),
            MigrationManagerToTimeouts(settings: fixture.settings, defaults: fixture.defaults),
        ]
        try await RuuviMigrationRunner.migrate(migrations)
        XCTAssertEqual(fixture.settings.dataPruningOffsetHours, 240)
        XCTAssertEqual(fixture.settings.chartDurationHours, 240)
        XCTAssertEqual(fixture.settings.networkPullIntervalSeconds, 60)
        XCTAssertEqual(fixture.settings.connectionTimeout, 30)
        XCTAssertEqual(fixture.settings.serviceTimeout, 60)
        fixture.settings.dataPruningOffsetHours = 120
        fixture.settings.chartDurationHours = 48
        fixture.settings.networkPullIntervalSeconds = 300
        fixture.settings.connectionTimeout = 10
        fixture.settings.serviceTimeout = 20
        try await RuuviMigrationRunner.migrate(migrations)
        XCTAssertEqual(fixture.settings.dataPruningOffsetHours, 120)
        XCTAssertEqual(fixture.settings.chartDurationHours, 48)
        XCTAssertEqual(fixture.settings.networkPullIntervalSeconds, 300)
        XCTAssertEqual(fixture.settings.connectionTimeout, 10)
        XCTAssertEqual(fixture.settings.serviceTimeout, 20)
    }

    func testDatabaseIsExcludedFromBackupAndMissingFileFailurePropagates() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let migration = MigrationManagerIsExcludedFromBackup(sqliteContext: fixture.context)
        try await migration.migrate()
        try await migration.migrate()
        let url = URL(fileURLWithPath: fixture.context.database.dbPath)
        XCTAssertEqual(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        try fixture.persistence.database.dbPool.close()
        try FileManager.default.removeItem(at: url)
        do { try await migration.migrate(); XCTFail("Missing database must report failure") } catch {}
    }

    func testFactoryKeepsDataDependencyOrder() throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let factory = RuuviMigrationFactoryImpl(
            settings: fixture.settings, idPersistence: fixture.ids, ruuviPool: fixture.pool,
            ruuviSensorProperties: fixture.properties, sqliteContext: fixture.context,
            ruuviStorage: fixture.storage, ruuviAlertService: fixture.alerts,
            ruuviOffsetCalibrationService: UnusedOffsetService())
        XCTAssertEqual(
            factory.createAllOrdered().map { String(describing: type(of: $0)) },
            [
                "MigrationManagerAlertService", "MigrationManagerToPrune240", "MigrationManagerToChartDuration240",
                "MigrationManagerSensorSettings", "MigrationManagerToRH", "MigrationManagerToTimeouts",
                "RuuviMigrationFixRHAlerts", "MigrationManagerToNetworkPull60", "MigrationManagerSignalVisibility",
                "MigrationManagerIsExcludedFromBackup",
            ])
    }

    func testLegacyOptionalValuesDistinguishAbsentZeroAndWrongType() throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        XCTAssertNil(fixture.defaults.optionalDouble(forKey: "legacy"))
        fixture.defaults.set(0.0, forKey: "legacy")
        XCTAssertEqual(fixture.defaults.optionalDouble(forKey: "legacy"), 0)
        fixture.defaults.set("corrupt", forKey: "legacy")
        XCTAssertNil(fixture.defaults.optionalDouble(forKey: "legacy"))
    }

    func testCalibrationPersistenceReadsLegacyKeysAndClearsDate() throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let identifier = UUID().uuidString.luid
        let persistence = CalibrationPersistenceUserDefaults(defaults: fixture.defaults)
        XCTAssertEqual(persistence.humidityOffset(for: identifier).0, 0)
        XCTAssertNil(persistence.humidityOffset(for: identifier).1)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        fixture.defaults.set(date, forKey: "CalibrationPersistenceUserDefaults.humidityOffsetDate" + identifier.value)
        fixture.defaults.set(-5.0, forKey: "CalibrationPersistenceUserDefaults.humidityOffset" + identifier.value)
        XCTAssertEqual(persistence.humidityOffset(for: identifier).0, -5)
        XCTAssertEqual(persistence.humidityOffset(for: identifier).1, date)
        persistence.setHumidity(date: nil, offset: 0, for: identifier)
        XCTAssertEqual(persistence.humidityOffset(for: identifier).0, 0)
        XCTAssertNil(persistence.humidityOffset(for: identifier).1)
    }

    func testConcurrentCallDoesNotRepeatReadsOrMarkIncompleteWorkFinished() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let started = expectation(description: "Read started")
        let gate = MigrationGate()
        fixture.storage.beforeReadAll = {
            started.fulfill(); await gate.wait()
        }
        let migration = fixture.humidityMigration
        let task = Task { @MainActor in try await migration.migrate() }
        await fulfillment(of: [started], timeout: 5)
        try await migration.migrate()
        XCTAssertEqual(fixture.storage.readAllCount, 1)
        XCTAssertFalse(fixture.defaults.bool(forKey: "MigrationManagerToRH.migrated"))
        gate.open()
        try await task.value
        XCTAssertTrue(fixture.defaults.bool(forKey: "MigrationManagerToRH.migrated"))
    }
}

@MainActor private final class MigrationGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var opened = false
    func wait() async {
        guard !opened else { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func open() { opened = true; continuation?.resume(); continuation = nil }
}

private struct BlockMigration: RuuviMigration {
    let body: @MainActor () async throws -> Void
    init(_ body: @escaping @MainActor () async throws -> Void) { self.body = body }
    @MainActor func migrate() async throws { try await body() }
}

private final class UnusedOffsetService: RuuviServiceOffsetCalibration {
    func set(
        offset: Double?, of type: OffsetCorrectionType, for sensor: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws(RuuviServiceError) -> SensorSettings {
        XCTFail("Factory construction must not migrate"); throw .macIdIsNil
    }
}
