import Foundation
import Future
import GRDB
@testable import RuuviContext
import RuuviOntology
@testable import RuuviPersistence
import XCTest

final class HistoryPersistenceTests: XCTestCase {
    private final class TestDatabase: GRDBDatabase {
        let dbPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite").path
        let dbPool: DatabasePool
        init() throws {
            dbPool = try DatabasePool(path: dbPath)
            try dbPool.write { db in
                try RuuviTagSQLite.createTable(in: db)
                try RuuviTagDataSQLite.createTable(in: db)
                try RuuviHistorySchema.create(in: db)
            }
        }

        func migrateIfNeeded() {}
        deinit { try? FileManager.default.removeItem(atPath: dbPath) }
    }

    private struct Context: SQLiteContext { let database: GRDBDatabase }
    private var database: TestDatabase!
    private var persistence: RuuviPersistenceSQLite!
    private let sensorID = "AA:BB:CC:DD:EE:FF"
    private let scope = "production|test@example.invalid"
    private var sensor: RuuviTagSensorStruct {
        RuuviTagSensorStruct(
            version: 6,
            firmwareVersion: nil,
            luid: nil,
            macId: sensorID.mac,
            serviceUUID: nil,
            isConnectable: true,
            name: "History test",
            isClaimed: true,
            isOwner: true,
            owner: nil,
            ownersPlan: nil,
            isCloudSensor: true,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: 100
        )
    }

    override func setUpWithError() throws {
        database = try TestDatabase()
        persistence = RuuviPersistenceSQLite(context: Context(database: database))
        XCTAssertTrue(try awaitResult(persistence.create(sensor)))
    }

    override func tearDown() { persistence = nil; database = nil }

    private func awaitResult<T>(
        _ future: Future<T, some Error>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> T {
        let done = expectation(description: "future completes")
        var result: Result<T, Error>?
        future.on(
            success: { result = .success($0); done.fulfill() },
            failure: { result = .failure($0); done.fulfill() }
        )
        wait(for: [done], timeout: 30)
        return try XCTUnwrap(result, file: file, line: line).get()
    }

    private func record(_ date: Date, value: Double = 1, sensorID: String? = nil) -> AnyRuuviTagSensorRecord {
        RuuviTagSensorRecordStruct(
            luid: nil,
            date: date,
            source: .ruuviNetwork,
            macId: (sensorID ?? self.sensorID).mac,
            rssi: -40,
            version: 6,
            temperature: nil,
            humidity: nil,
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
            voc: value,
            nox: value,
            luminance: nil,
            dbaInstant: nil,
            dbaAvg: nil,
            dbaPeak: nil,
            temperatureOffset: 0,
            humidityOffset: 0,
            pressureOffset: 0
        ).any
    }

    private func coverage(freshAfter: Date = .distantPast, scope: String? = nil) throws -> RuuviHistoryCoverage {
        try awaitResult(persistence.historyCoverage(sensorID, scope: scope ?? self.scope, freshAfter: freshAfter))
    }

    private func save(
        _ records: [AnyRuuviTagSensorRecord],
        range: RuuviHistoryRange,
        generation: Int = 0,
        cancellation: RuuviHistoryCancellation = RuuviHistoryCancellation()
    ) throws -> Bool {
        try awaitResult(persistence.saveHistoryPage(
            sensorID,
            records: records,
            range: range,
            scope: scope,
            generation: generation,
            cancellation: cancellation
        ))
    }

    func testPageFiltersBoundsAndSensorAndDuplicatePagesDoNotChangeRevision() throws {
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970)).addingTimeInterval(-1000)
        let range = RuuviHistoryRange(start: start, end: start.addingTimeInterval(100))
        let records = [record(start.addingTimeInterval(-1)), record(start), record(start.addingTimeInterval(50)),
                       record(range.end), record(start.addingTimeInterval(25), sensorID: "11:22:33:44:55:66")]
        XCTAssertTrue(try save(records, range: range))
        XCTAssertEqual(try awaitResult(persistence.readAll(sensorID)).count, 2)
        let revision = try awaitResult(persistence.historyRevision(sensorID))
        XCTAssertTrue(try save(records, range: range))
        XCTAssertEqual(try awaitResult(persistence.historyRevision(sensorID)), revision)
        XCTAssertEqual(try coverage().ranges, [range])
    }

    func testEmptyPageEstablishesCoverageAndScopesAreIsolated() throws {
        let range = RuuviHistoryRange(start: Date().addingTimeInterval(-1000), end: Date().addingTimeInterval(-500))
        XCTAssertTrue(try save([], range: range))
        XCTAssertEqual(try coverage().ranges, [range])
        XCTAssertTrue(try coverage(scope: "testnet|test@example.invalid").ranges.isEmpty)
        XCTAssertTrue(try coverage(scope: "production|another@example.invalid").ranges.isEmpty)
        XCTAssertEqual(try awaitResult(persistence.historyRevision(sensorID)), 0)
    }

    func testFailureRollsBackBothReadingsAndCoverage() throws {
        try database.dbPool.write { db in
            try db
                .execute(
                    sql: "CREATE TRIGGER fail_test BEFORE INSERT ON ruuvi_tag_sensor_records WHEN NEW.nox = 999 BEGIN SELECT RAISE(ABORT, 'test failure'); END"
                )
        }
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970)).addingTimeInterval(-1000)
        let range = RuuviHistoryRange(start: start, end: start.addingTimeInterval(100))
        XCTAssertThrowsError(try save([record(start), record(start.addingTimeInterval(50), value: 999)], range: range))
        XCTAssertTrue(try awaitResult(persistence.readAll(sensorID)).isEmpty)
        XCTAssertTrue(try coverage().ranges.isEmpty)
        XCTAssertEqual(try awaitResult(persistence.historyRevision(sensorID)), 0)
    }

    func testClearAndCancellationRejectInFlightPages() throws {
        let range = RuuviHistoryRange(start: Date().addingTimeInterval(-1000), end: Date().addingTimeInterval(-500))
        let generation = try coverage().generation
        _ = try awaitResult(persistence.deleteAllRecords(sensorID))
        XCTAssertFalse(try save([record(range.start)], range: range, generation: generation))
        let cancellation = RuuviHistoryCancellation()
        cancellation.cancel()
        XCTAssertFalse(try save(
            [record(range.start)],
            range: range,
            generation: coverage().generation,
            cancellation: cancellation
        ))
        XCTAssertTrue(try awaitResult(persistence.readAll(sensorID)).isEmpty)
        XCTAssertTrue(try coverage().ranges.isEmpty)
    }

    func testCancellationDuringPageWriteRollsBackReadingsAndCoverage() throws {
        let cancellation = RuuviHistoryCancellation()
        try database.dbPool.write { db in
            db.add(function: DatabaseFunction("cancel_history_test", argumentCount: 0) { _ in
                cancellation.cancel()
                return 0
            })
            try db
                .execute(
                    sql: "CREATE TRIGGER cancel_history_test AFTER INSERT ON ruuvi_tag_sensor_records BEGIN SELECT cancel_history_test(); END"
                )
        }
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970)).addingTimeInterval(-1000)
        let range = RuuviHistoryRange(start: start, end: start.addingTimeInterval(100))
        XCTAssertFalse(try save(
            [record(start), record(start.addingTimeInterval(50))],
            range: range,
            cancellation: cancellation
        ))
        XCTAssertTrue(try awaitResult(persistence.readAll(sensorID)).isEmpty)
        XCTAssertTrue(try coverage().ranges.isEmpty)
        XCTAssertEqual(try awaitResult(persistence.historyRevision(sensorID)), 0)
    }

    func testDeletingSensorRejectsItsPendingPage() throws {
        let range = RuuviHistoryRange(start: Date().addingTimeInterval(-1000), end: Date().addingTimeInterval(-500))
        XCTAssertTrue(try awaitResult(persistence.delete(sensor)))
        XCTAssertFalse(try save([record(range.start)], range: range))
        XCTAssertTrue(try coverage().ranges.isEmpty)
    }

    func testRetryKeepsCompletedPageAndRequestsOnlyMissingRemainder() throws {
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970)).addingTimeInterval(-1000)
        let whole = RuuviHistoryRange(start: start, end: start.addingTimeInterval(500))
        let firstPage = RuuviHistoryRange(start: start, end: start.addingTimeInterval(200))
        XCTAssertTrue(try save([record(start)], range: firstPage))
        XCTAssertEqual(
            try whole.uncovered(by: coverage(freshAfter: Date().addingTimeInterval(-86400)).ranges),
            [RuuviHistoryRange(start: firstPage.end, end: whole.end)]
        )
    }

    func testPartialRevalidationPreservesAgeOfUncheckedRanges() throws {
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970)).addingTimeInterval(-1000)
        let whole = RuuviHistoryRange(start: start, end: start.addingTimeInterval(500))
        XCTAssertTrue(try save([], range: whole))
        try database.dbPool.write { db in
            try db.execute(
                sql: "UPDATE history_coverage SET fetched = ?",
                arguments: [Date().addingTimeInterval(-172_800).timeIntervalSince1970]
            )
        }
        let middle = RuuviHistoryRange(start: start.addingTimeInterval(100), end: start.addingTimeInterval(200))
        for _ in 0 ..< 4 {
            XCTAssertTrue(try save([], range: middle))
        }
        XCTAssertEqual(try coverage(freshAfter: Date().addingTimeInterval(-86400)).ranges, [middle])
        XCTAssertEqual(try coverage().ranges.count, 3)
    }

    func testScanIsOrderedBoundedAndCancellable() throws {
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970)).addingTimeInterval(-1000)
        _ = try awaitResult(persistence.create([
            record(start.addingTimeInterval(90)),
            record(start),
            record(start.addingTimeInterval(50))
        ]))
        let range = RuuviHistoryRange(start: start, end: start.addingTimeInterval(90))
        var dates: [Date] = []
        _ = try awaitResult(
            persistence
                .scanHistory(sensorID, range: range, cancellation: RuuviHistoryCancellation()) { dates.append($0.date) }
        )
        XCTAssertEqual(
            dates.map { Int($0.timeIntervalSince1970) },
            [start, start.addingTimeInterval(50)].map { Int($0.timeIntervalSince1970) }
        )
        let cancellation = RuuviHistoryCancellation()
        cancellation.cancel()
        let revision = try awaitResult(
            persistence.scanHistory(sensorID, range: range, cancellation: cancellation) { _ in
                XCTFail("Cancelled scan emitted a record")
            }
        )
        XCTAssertEqual(revision, -1)
    }

    func testRangeQueryUsesOrderedIndexesWithoutSortingRawHistory() throws {
        let now = Date()
        let plan = try database.dbPool.read { db in
            try Row.fetchAll(
                db,
                sql: "EXPLAIN QUERY PLAN " + RuuviPersistenceSQLite.boundedHistorySQL,
                arguments: [
                    sensorID,
                    now.addingTimeInterval(-86400),
                    now,
                    "local-id",
                    sensorID,
                    now.addingTimeInterval(-86400),
                    now
                ]
            )
            .map { (row: Row) -> String in row["detail"] }.joined(separator: "\n")
        }
        XCTAssertTrue(plan.contains("history_mac_date"), plan)
        XCTAssertTrue(plan.contains("history_luid_date"), plan)
        XCTAssertFalse(plan.contains("TEMP B-TREE"), plan)
    }

    func testRetentionRejectsOldIngestion() throws {
        let old = record(Date().addingTimeInterval(-Double(RuuviHistoryRange.retentionDays + 1) * 86400))
        _ = try awaitResult(persistence.create(old))
        _ = try awaitResult(persistence.create([
            old,
            record(Date().addingTimeInterval(-Double(RuuviHistoryRange.retentionDays - 1) * 86400))
        ]))
        XCTAssertEqual(try awaitResult(persistence.readAll(sensorID)).count, 1)
    }

    func testBulkImportDeduplicatesAcrossPageBoundaries() throws {
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970)).addingTimeInterval(-20000)
        var records = (0 ... 5000).map { record(start.addingTimeInterval(Double($0 * 2))) }
        records.append(record(start.addingTimeInterval(4999 * 2)))
        _ = try awaitResult(persistence.create(records))
        XCTAssertEqual(try awaitResult(persistence.readAll(sensorID)).count, 5001)
    }
}
