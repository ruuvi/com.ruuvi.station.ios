import Foundation
import GRDB
import RuuviOntology
import RuuviPersistence
import RuuviPool
import XCTest

@MainActor final class RuuviPoolTests: XCTestCase {
    func testSuccessfulSensorWritesPublishBothIdentifierDirectionsAfterSaving() async throws {
        let fixture = try PoolDatabaseFixture()
        defer { fixture.close() }
        let sensor = fixture.sensor()
        let created = try await fixture.pool.create(sensor)
        XCTAssertTrue(created)
        let stored = try await fixture.persistence.readOne(sensor.id)
        XCTAssertEqual(stored.name, "Room")
        XCTAssertEqual(fixture.ids.mac(for: fixture.luid)?.value, fixture.mac.value)
        XCTAssertEqual(fixture.ids.luid(for: fixture.mac)?.value, fixture.luid.value)
        XCTAssertEqual(fixture.ids.writes, 2)
        let updated = try await fixture.pool.update(sensor.with(name: "Kitchen"))
        XCTAssertTrue(updated)
        let renamed = try await fixture.persistence.readOne(sensor.id)
        XCTAssertEqual(renamed.name, "Kitchen")
        XCTAssertEqual(fixture.ids.writes, 4)
    }

    func testFailedSensorWritesDoNotChangeIdentifierMappings() async throws {
        let fixture = try PoolDatabaseFixture()
        defer { fixture.close() }
        try fixture.context.database.dbPool.close()
        for operation: () async throws -> Void in [
            { _ = try await fixture.pool.create(fixture.sensor()) },
            { _ = try await fixture.pool.update(fixture.sensor()) },
        ] {
            do { try await operation(); XCTFail("Closed database must reject the write") } catch {
                guard let error = error as? RuuviPoolError, case .ruuviPersistence(.grdb) = error
                else { return XCTFail("Unexpected error: \(error)") }
            }
            XCTAssertTrue(fixture.ids.macs.isEmpty)
            XCTAssertTrue(fixture.ids.luids.isEmpty)
            XCTAssertEqual(fixture.ids.writes, 0)
        }
    }

    func testMissingAndEmptySensorMACsAreRejectedBeforeChangingMappings() async throws {
        let fixture = try PoolDatabaseFixture()
        defer { fixture.close() }
        for mac: MACIdentifier? in [nil, "".mac] {
            var sensor = fixture.sensor()
            sensor.macId = mac
            for operation: () async throws -> Void in [
                { _ = try await fixture.pool.create(sensor) },
                { _ = try await fixture.pool.update(sensor) },
            ] {
                await assertMissingIdentity(operation)
            }
        }
        XCTAssertEqual(fixture.ids.writes, 0)
        let count = try await fixture.persistence.getStoredTagsCount()
        XCTAssertEqual(count, 0)
    }

    func testLocalRecordsResolveMissingOrEmptyMACsForHistoryAndLatestWrites() async throws {
        for mac: MACIdentifier? in [nil, "".mac] {
            let fixture = try PoolDatabaseFixture()
            defer { fixture.close() }
            fixture.ids.macs[fixture.luid.value] = fixture.mac.value
            var record = fixture.record()
            record.macId = mac
            _ = try await fixture.pool.create(record)
            _ = try await fixture.pool.createLast(record)
            record.temperature = .init(value: 22, unit: .celsius)
            _ = try await fixture.pool.updateLast(record)
            let history = try await fixture.persistence.readAll(fixture.luid.value)
            let latest = try await fixture.persistence.readLatest(fixture.sensor())
            XCTAssertEqual(history.count, 1)
            XCTAssertEqual(history.first?.macId?.value, fixture.mac.value)
            XCTAssertEqual(latest?.macId?.value, fixture.mac.value)
            XCTAssertEqual(latest?.temperature?.value, 22)
        }
    }

    func testUnresolvableRecordsAndMixedBatchesFailWithoutDiscardingMeasurements() async throws {
        let fixture = try PoolDatabaseFixture()
        defer { fixture.close() }
        for mac: MACIdentifier? in [nil, "".mac] {
            var record = fixture.record()
            record.macId = mac
            await assertMissingIdentity { _ = try await fixture.pool.create(record) }
            await assertMissingIdentity { _ = try await fixture.pool.createLast(record) }
            await assertMissingIdentity { _ = try await fixture.pool.updateLast(record) }
            await assertMissingIdentity { _ = try await fixture.pool.create([fixture.record(), record]) }
        }
        let count = try await fixture.persistence.getStoredMeasurementsCount()
        XCTAssertEqual(count, 0)
        fixture.ids.macs[fixture.luid.value] = ""
        var record = fixture.record()
        record.macId = nil
        await assertMissingIdentity { _ = try await fixture.pool.create(record) }
    }

    func testFailedSensorDeletionPreservesCalibrationAndConnectionUntilAnAtomicDeleteSucceeds() async throws {
        let fixture = try PoolDatabaseFixture()
        defer { fixture.close() }
        let sensor = fixture.sensor()
        _ = try await fixture.pool.create(sensor)
        _ = try await fixture.pool.updateOffsetCorrection(type: .temperature, with: 2, of: sensor)
        fixture.connections.paired.insert(fixture.luid.value)
        try await fixture.context.database.dbPool.write { db in
            try db.execute(
                sql: """
                    CREATE TRIGGER deny_sensor_delete BEFORE DELETE ON ruuvi_tag_sensors
                    BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END;
                    """)
        }
        do { _ = try await fixture.pool.delete(sensor); XCTFail("Deletion must fail") } catch {
            guard let error = error as? RuuviPoolError, case .ruuviPersistence(.grdb) = error
            else { return XCTFail("Unexpected error: \(error)") }
        }
        let retained = try await fixture.persistence.readOne(sensor.id)
        let settings = try await fixture.persistence.readSensorSettings(sensor)
        XCTAssertEqual(retained.id, sensor.id)
        XCTAssertEqual(settings?.temperatureOffset, 2, "A failed deletion must preserve calibration")
        XCTAssertTrue(fixture.connections.keepConnection(to: fixture.luid))
        try await fixture.context.database.dbPool.write { db in try db.execute(sql: "DROP TRIGGER deny_sensor_delete") }
        let deleted = try await fixture.pool.delete(sensor)
        XCTAssertTrue(deleted)
        let remainingSettings = try await fixture.persistence.readSensorSettings(sensor)
        XCTAssertNil(remainingSettings)
        XCTAssertFalse(fixture.connections.keepConnection(to: fixture.luid))
    }

    private func assertMissingIdentity(
        file: StaticString = #filePath, line: UInt = #line, _ operation: () async throws -> Void
    ) async {
        do { try await operation(); XCTFail("Expected missing identity", file: file, line: line) } catch {
            guard let error = error as? RuuviPoolError, case .ruuviPersistence(.failedToFindRuuviTag) = error
            else { return XCTFail("Unexpected identity error: \(error)", file: file, line: line) }
        }
    }
}
