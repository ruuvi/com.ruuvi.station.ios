import Foundation
import GRDB
import RuuviOntology
import RuuviPersistence
import RuuviPool
import XCTest

@MainActor final class PoolFailureTests: XCTestCase {
    func testAllStorageFailuresPreserveTheOriginalErrorAcrossThePoolBoundary() async throws {
        let fixture = try PoolDatabaseFixture()
        defer { fixture.close() }
        let pool = fixture.pool
        let sensor = fixture.sensor()
        let record = fixture.record()
        let request = RuuviCloudQueuedRequestStruct(
            id: 1, type: .sensor, status: .failed, uniqueKey: "sensor",
            requestDate: fixture.date, successDate: nil, attempts: 0, requestBodyData: Data(), additionalData: nil)
        let subscription = PoolSubscription(macId: fixture.mac.value)
        try fixture.context.database.dbPool.close()
        let operations: [(String, () async throws -> Void)] = [
            ("delete sensor", { _ = try await pool.delete(sensor) }),
            ("delete settings", { _ = try await pool.deleteSensorSettings(sensor) }),
            ("create history", { _ = try await pool.create(record) }),
            ("create latest", { _ = try await pool.createLast(record) }),
            ("update latest", { _ = try await pool.updateLast(record) }),
            ("create batch", { _ = try await pool.create([record]) }),
            ("delete latest", { _ = try await pool.deleteLast(sensor.id) }),
            ("delete history", { _ = try await pool.deleteAllRecords(sensor.id) }),
            ("prune history", { _ = try await pool.deleteAllRecords(sensor.id, before: fixture.date) }),
            ("vacuum", { _ = try await pool.cleanupDBSpace() }),
            ("calibration", { _ = try await pool.updateOffsetCorrection(type: .temperature, with: 2, of: sensor) }),
            (
                "display settings",
                {
                    _ = try await pool.updateDisplaySettings(
                        for: sensor, displayOrder: [], defaultDisplayOrder: false,
                        displayOrderLastUpdated: fixture.date, defaultDisplayOrderLastUpdated: fixture.date)
                }
            ),
            (
                "description",
                {
                    _ = try await pool.updateDescription(
                        for: sensor, description: "Room", descriptionLastUpdated: fixture.date)
                }
            ),
            ("read settings", { _ = try await pool.readSensorSettings(sensor) }),
            ("queue request", { _ = try await pool.createQueuedRequest(request) }),
            ("delete request", { _ = try await pool.deleteQueuedRequest(request) }),
            ("delete all requests", { _ = try await pool.deleteQueuedRequests() }),
            ("delete user settings", { _ = try await pool.deleteUserSettings() }),
            ("save subscription", { _ = try await pool.save(subscription: subscription) }),
            ("read subscription", { _ = try await pool.readSensorSubscriptionSettings(sensor) }),
        ]
        for (name, operation) in operations {
            do { try await operation(); XCTFail("\(name) must report storage failure") } catch {
                guard let error = error as? RuuviPoolError, case .ruuviPersistence(.grdb(let underlying)) = error
                else { XCTFail("\(name): unexpected error \(error)"); continue }
                XCTAssertTrue(underlying is DatabaseError, "\(name) must preserve the SQLite error")
            }
        }
        fixture.ids.macs[fixture.luid.value] = fixture.mac.value
        var local = record
        local.macId = nil
        for operation: () async throws -> Void in [
            { _ = try await pool.create(local) },
            { _ = try await pool.createLast(local) },
            { _ = try await pool.updateLast(local) },
        ] {
            do { try await operation(); XCTFail("Resolved local writes must propagate storage failure") } catch {
                guard let error = error as? RuuviPoolError, case .ruuviPersistence(.grdb(let underlying)) = error
                else { return XCTFail("Unexpected local record error: \(error)") }
                XCTAssertTrue(underlying is DatabaseError)
            }
        }
    }

    func testCalibrationDeleteFailureRollsBackTheSensorDeletion() async throws {
        let fixture = try PoolDatabaseFixture()
        defer { fixture.close() }
        let sensor = fixture.sensor()
        _ = try await fixture.pool.create(sensor)
        _ = try await fixture.pool.updateOffsetCorrection(type: .temperature, with: 2, of: sensor)
        fixture.connections.paired.insert(fixture.luid.value)
        try await fixture.context.database.dbPool.write { db in
            try db.execute(
                sql: """
                    CREATE TRIGGER deny_settings_delete BEFORE DELETE ON sensor_settings
                    BEGIN SELECT RAISE(ABORT, 'simulated calibration failure'); END;
                    """)
        }
        do { _ = try await fixture.pool.delete(sensor); XCTFail("Deletion must roll back") } catch {
            guard let error = error as? RuuviPoolError, case .ruuviPersistence(.grdb) = error
            else { return XCTFail("Unexpected error: \(error)") }
        }
        let retained = try await fixture.persistence.readOne(sensor.id)
        let settings = try await fixture.persistence.readSensorSettings(sensor)
        XCTAssertEqual(retained.name, "Room")
        XCTAssertEqual(settings?.temperatureOffset, 2)
        XCTAssertTrue(fixture.connections.keepConnection(to: fixture.luid))
    }

    func testDeletingAnUnsavedSensorDoesNotCreateIdentifierMappings() async throws {
        let fixture = try PoolDatabaseFixture()
        defer { fixture.close() }
        let deleted = try await fixture.pool.delete(fixture.sensor())
        XCTAssertFalse(deleted)
        XCTAssertEqual(fixture.ids.writes, 0)
    }
}

private struct PoolSubscription: CloudSensorSubscription {
    var macId: String?
    var subscriptionName: String? = "Pro"
    var isActive: Bool? = true
    var maxClaims: Int? = 10
    var maxHistoryDays: Int? = 365
    var maxResolutionMinutes: Int? = 1
    var maxShares: Int? = 10
    var maxSharesPerSensor: Int? = 10
    var delayedAlertAllowed: Bool? = true
    var emailAlertAllowed: Bool? = true
    var offlineAlertAllowed: Bool? = true
    var pdfExportAllowed: Bool? = true
    var pushAlertAllowed: Bool? = true
    var telegramAlertAllowed: Bool? = true
    var endAt: String?
}
