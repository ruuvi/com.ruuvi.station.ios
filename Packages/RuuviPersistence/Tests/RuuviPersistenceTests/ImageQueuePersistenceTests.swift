import RuuviPersistence
import RuuviContext
import RuuviOntology
import Future
import GRDB
import XCTest

final class ImageQueuePersistenceTests: XCTestCase {
    func testDatabaseReadFailureCompletesInsteadOfHanging() throws {
        let database = try QueueTestDatabase(createTable: false)
        let persistence = RuuviPersistenceSQLite(context: QueueTestContext(database: database))
        let finished = expectation(description: "Missing queue table reported")
        persistence.createQueuedRequest(request(at: 100)).on(success: { _ in XCTFail("Expected database failure") },
                                                            failure: { _ in finished.fulfill() })
        wait(for: [finished], timeout: 2)
    }

    func testDelayedOldFailureCannotReplaceNewerPhotoRetry() throws {
        let database = try QueueTestDatabase()
        let persistence = RuuviPersistenceSQLite(context: QueueTestContext(database: database))
        waitSuccess(persistence.createQueuedRequest(request(at: 200)))
        waitSuccess(persistence.createQueuedRequest(request(at: 100)))
        let requests = try database.dbPool.read { try RuuviCloudQueuedRequestSQLite.fetchAll($0) }
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.requestDate, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(requests.first?.additionalData, Data([200]))
    }

    func testCompletionOfOlderRetryCannotDeleteReplacement() throws {
        let database = try QueueTestDatabase()
        let persistence = RuuviPersistenceSQLite(context: QueueTestContext(database: database))
        waitSuccess(persistence.createQueuedRequest(request(at: 100)))
        let old = try database.dbPool.read { try XCTUnwrap(RuuviCloudQueuedRequestSQLite.fetchOne($0)) }
        waitSuccess(persistence.createQueuedRequest(request(at: 200)))
        waitSuccess(persistence.deleteQueuedRequest(old))
        let remaining = try database.dbPool.read { try RuuviCloudQueuedRequestSQLite.fetchAll($0) }
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.requestDate, Date(timeIntervalSince1970: 200))
    }

    func testConcurrentFailuresProduceOneNewestRetry() throws {
        let database = try QueueTestDatabase()
        let persistence = RuuviPersistenceSQLite(context: QueueTestContext(database: database))
        let requests = (1...20).reversed().map { persistence.createQueuedRequest(request(at: $0)) }
        let finished = expectation(description: "All queue writes completed")
        Future.zip(requests).on(success: { _ in finished.fulfill() }, failure: { XCTFail("\($0)") })
        wait(for: [finished], timeout: 3)
        let remaining = try database.dbPool.read { try RuuviCloudQueuedRequestSQLite.fetchAll($0) }
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.requestDate, Date(timeIntervalSince1970: 20))
    }

    func testAcknowledgementDoesNotDeleteNewerQueuedImage() throws {
        let database = try QueueTestDatabase()
        let persistence = RuuviPersistenceSQLite(context: QueueTestContext(database: database))
        waitSuccess(persistence.createQueuedRequest(request(at: 200)))
        waitSuccess(persistence.deleteQueuedImageUploads(
            for: "AA:BB:CC:DD:EE:FF".mac, through: Date(timeIntervalSince1970: 100)
        ))
        let remaining = try database.dbPool.read { try RuuviCloudQueuedRequestSQLite.fetchAll($0) }
        XCTAssertEqual(remaining.count, 1)
        waitSuccess(persistence.deleteQueuedImageUploads(
            for: "AA:BB:CC:DD:EE:FF".mac, through: Date(timeIntervalSince1970: 200)
        ))
        XCTAssertTrue(try database.dbPool.read { try RuuviCloudQueuedRequestSQLite.fetchAll($0) }.isEmpty)
    }

    func testExplicitAcknowledgementRetiresLegacyRetryUnderMacAlias() throws {
        let database = try QueueTestDatabase()
        let persistence = RuuviPersistenceSQLite(context: QueueTestContext(database: database))
        var legacy = request(at: 100)
        legacy.requestDate = nil
        legacy.uniqueKey = "00:00:00:DD:EE:FF-uploadImage"
        waitSuccess(persistence.createQueuedRequest(legacy))
        waitSuccess(persistence.deleteQueuedImageUploads(
            for: "AA:BB:CC:DD:EE:FF".mac, through: Date(timeIntervalSince1970: 200)
        ))
        XCTAssertTrue(try database.dbPool.read { try RuuviCloudQueuedRequestSQLite.fetchAll($0) }.isEmpty)
    }

    func testSensorRemovalDeletesOnlyItsImageRetries() throws {
        let database = try QueueTestDatabase()
        try database.dbPool.write { try RuuviTagSQLite.createTable(in: $0) }
        let persistence = RuuviPersistenceSQLite(context: QueueTestContext(database: database))
        let sensor = CloudSensorStruct(
            id: "AA:BB:CC:DD:EE:FF", serviceUUID: nil, name: "Sensor", isClaimed: true, isOwner: true,
            owner: "owner@example.com", ownersPlan: "free", picture: nil,
            offsetTemperature: nil, offsetHumidity: nil, offsetPressure: nil, isCloudSensor: true,
            canShare: true, sharedTo: [], sharedToPending: [], maxHistoryDays: 30, lastUpdated: nil
        ).ruuviTagSensor
        waitSuccess(persistence.create(sensor))
        waitSuccess(persistence.createQueuedRequest(request(at: 100)))
        var unrelated = request(at: 200)
        unrelated.uniqueKey = "AA:BB:CC:11:22:33-uploadImage"
        waitSuccess(persistence.createQueuedRequest(unrelated))
        waitSuccess(persistence.delete(sensor))
        let remaining = try database.dbPool.read { try RuuviCloudQueuedRequestSQLite.fetchAll($0) }
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.uniqueKey, unrelated.uniqueKey)
    }

    private func waitSuccess(_ future: Future<Bool, RuuviPersistenceError>) {
        let finished = expectation(description: "Queue operation completed")
        future.on(success: { _ in finished.fulfill() }, failure: { XCTFail("\($0)") })
        wait(for: [finished], timeout: 2)
    }

    private func request(at seconds: Int) -> RuuviCloudQueuedRequestStruct {
        RuuviCloudQueuedRequestStruct(
            id: nil, type: .uploadImage, status: .failed, uniqueKey: "AA:BB:CC:DD:EE:FF-uploadImage",
            requestDate: Date(timeIntervalSince1970: Double(seconds)), successDate: nil, attempts: nil,
            requestBodyData: Data("upload".utf8), additionalData: Data([UInt8(seconds)])
        )
    }
}

private struct QueueTestContext: SQLiteContext {
    let database: GRDBDatabase
}

private final class QueueTestDatabase: GRDBDatabase {
    let dbPool: DatabasePool
    let dbPath: String
    init(createTable: Bool = true) throws {
        dbPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite").path
        dbPool = try DatabasePool(path: dbPath)
        if createTable { try dbPool.write { try RuuviCloudQueuedRequestSQLite.createTable(in: $0) } }
    }
    func migrateIfNeeded() {
        // Each test creates exactly the schema it needs in init; production migrations are intentionally skipped.
    }
    deinit {
        try? dbPool.close()
        try? FileManager.default.removeItem(atPath: dbPath)
    }
}
