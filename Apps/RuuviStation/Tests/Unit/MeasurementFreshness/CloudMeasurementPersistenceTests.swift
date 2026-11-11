import GRDB
import RuuviContext
import RuuviOntology
import RuuviPersistence
import XCTest

@MainActor
final class CloudMeasurementPersistenceTests: XCTestCase {
    private let mac = "FA:CE:00:00:00:01"

    func testCommitNotificationsFollowPersistedWritesEvenWhenTimestampMovesBackwards() async throws {
        let fixture = try MeasurementDatabaseFixture()
        let persistence = RuuviPersistenceSQLite(context: fixture)
        var commits: [RuuviCloudMeasurementCommit] = []
        let token = observe { commits.append($0) }
        defer { NotificationCenter.default.removeObserver(token) }
        let newer = Date(timeIntervalSince1970: 1_800_000_000.123456)
        let older = newer.addingTimeInterval(-7200)
        XCTAssertEqual(persistence.createLast(record(date: newer)).value, true)
        let firstStored = try storedDate(in: fixture)
        XCTAssertEqual(persistence.updateLast(record(date: older)).value, true)
        let finalStored = try storedDate(in: fixture)
        await drainMainQueue()
        XCTAssertEqual(commits.map(\.date), [firstStored, finalStored])
        XCTAssertLessThan(try XCTUnwrap(commits.last?.date), try XCTUnwrap(commits.first?.date))
    }

    func testRollbackAfterInsertEmitsNoCommitAndLeavesNoRecord() async throws {
        let fixture = try MeasurementDatabaseFixture()
        let persistence = RuuviPersistenceSQLite(context: fixture)
        try await fixture.dbPool.write { db in
            try db.execute(sql: "CREATE TABLE parent (id INTEGER PRIMARY KEY)")
            try db.execute(sql: """
                CREATE TABLE deferred_guard (
                    parent_id INTEGER REFERENCES parent(id) DEFERRABLE INITIALLY DEFERRED
                )
                """)
            try db.execute(sql: """
                CREATE TRIGGER reject_latest AFTER INSERT ON ruuvi_tag_sensor_record_latest
                BEGIN INSERT INTO deferred_guard VALUES (1); END
                """)
        }
        var commits: [RuuviCloudMeasurementCommit] = []
        let token = observe { commits.append($0) }
        defer { NotificationCenter.default.removeObserver(token) }
        XCTAssertNotNil(persistence.createLast(record(date: Date())).error)
        await drainMainQueue()
        XCTAssertTrue(commits.isEmpty)
        let count = try await fixture.dbPool.read { try RuuviTagLatestDataSQLite.fetchCount($0) }
        XCTAssertEqual(count, 0)
    }

    func testLocalWritesAndFailedCloudUpdatesDoNotPublishCloudCommits() async throws {
        let fixture = try MeasurementDatabaseFixture()
        let persistence = RuuviPersistenceSQLite(context: fixture)
        var commits: [RuuviCloudMeasurementCommit] = []
        let token = observe { commits.append($0) }
        defer { NotificationCenter.default.removeObserver(token) }
        XCTAssertNotNil(persistence.updateLast(record(date: Date())).error)
        XCTAssertEqual(persistence.createLast(record(date: Date(), source: .advertisement)).value, true)
        await drainMainQueue()
        XCTAssertTrue(commits.isEmpty)
    }

    private func storedDate(in fixture: MeasurementDatabaseFixture) throws -> Date {
        try fixture.dbPool.read { db in
            try XCTUnwrap(RuuviTagLatestDataSQLite.fetchOne(db, key: mac)?.date)
        }
    }

    private func observe(_ receive: @escaping (RuuviCloudMeasurementCommit) -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: RuuviCloudMeasurementCommit.notification, object: nil, queue: .main
        ) { [mac] notification in
            guard let commit = notification.userInfo?[RuuviCloudMeasurementCommit.userInfoKey]
                as? RuuviCloudMeasurementCommit, commit.mac == mac else { return }
            receive(commit)
        }
    }

    private func drainMainQueue() async {
        let drained = expectation(description: "Queued commit notifications delivered")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
    }

    private func record(date: Date, source: RuuviTagSensorRecordSource = .ruuviNetwork) -> RuuviTagSensorRecord {
        RuuviTagSensorRecordStruct(
            luid: nil, date: date, source: source, macId: mac.mac, rssi: nil, version: 5,
            temperature: nil, humidity: nil, pressure: nil, acceleration: nil, voltage: nil,
            movementCounter: nil, measurementSequenceNumber: nil, txPower: nil,
            pm1: nil, pm25: nil, pm4: nil, pm10: nil, co2: nil, voc: nil, nox: nil,
            luminance: nil, dbaInstant: nil, dbaAvg: nil, dbaPeak: nil,
            temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0
        )
    }
}

private final class MeasurementDatabaseFixture: SQLiteContext, GRDBDatabase {
    let dbPool: DatabasePool
    let dbPath: String
    private let directory: URL
    var database: GRDBDatabase { self }

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        dbPath = directory.appendingPathComponent("measurements.sqlite").path
        dbPool = try DatabasePool(path: dbPath)
        try dbPool.write { db in
            try RuuviTagSQLite.createTable(in: db)
            try RuuviTagLatestDataSQLite.createTable(in: db)
        }
    }

    func migrateIfNeeded() {
        // The disposable fixture creates its complete test schema during initialization.
    }

    deinit { try? FileManager.default.removeItem(at: directory) }
}
