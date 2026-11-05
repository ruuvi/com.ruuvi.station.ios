import Foundation
import GRDB
import RuuviAnalytics
import RuuviContext
import RuuviOntology
import RuuviPersistence
import RuuviReactor
#if SWIFT_PACKAGE
    import RuuviContextSQLite
    import RuuviPersistenceSQLite
    import RuuviReactorImpl
#endif
import XCTest

@MainActor final class ReactorObservationTests: XCTestCase {
    func testHistoryIsOrderedByDateAndScopedToTheLocalIdentifier() async throws {
        let fixture = try ReactorDatabaseFixture()
        defer { fixture.close() }
        let initial = expectation(description: "Initial empty history")
        let history = expectation(description: "Chronological history")
        var snapshots = [[Date]]()
        let token = fixture.reactor.observe(fixture.luid) { values in
            XCTAssertTrue(Thread.isMainThread)
            snapshots.append(values.map(\.date))
            if snapshots.count == 1 {
                XCTAssertTrue(values.isEmpty)
                initial.fulfill()
            } else {
                XCTAssertEqual(values.map { $0.temperature?.value }, [10, 20])
                history.fulfill()
            }
        }
        await fulfillment(of: [initial], timeout: 3)
        _ = try await fixture.store.create([
            fixture.record(seconds: 20), fixture.record(seconds: 10),
            fixture.record(seconds: 30, luid: "other".luid, mac: "11:22:33:44:55:66".mac),
        ])
        await fulfillment(of: [history], timeout: 3)
        XCTAssertEqual(snapshots.last, [fixture.date.addingTimeInterval(10), fixture.date.addingTimeInterval(20)])
        token.invalidate()
        _ = try await fixture.store.create(fixture.record(seconds: 40))
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(snapshots.count, 2)
    }

    func testLastAndLatestUseLocalIdentityLegacyMACSuffixAndExactShortIdentifiers() async throws {
        for (local, sensorMAC, recordMAC) in [
            (true, nil, "AA:BB:CC:DD:EE:FF"),
            (false, "FF:EE:CC:DD:EE:FF", "AA:BB:CC:DD:EE:FF"),
            (false, "short", "short"),
        ] {
            let fixture = try ReactorDatabaseFixture()
            defer { fixture.close() }
            let sensor = fixture.sensor(luid: local ? fixture.luid : nil, mac: sensorMAC?.mac)
            _ = try await fixture.store.create([
                fixture.record(seconds: 10, mac: recordMAC.mac),
                fixture.record(seconds: 20, mac: recordMAC.mac),
                fixture.record(seconds: 50, luid: "other".luid, mac: "unrelated".mac),
            ])
            _ = try await fixture.store.createLast(fixture.record(seconds: 30, mac: recordMAC.mac))
            _ = try await fixture.store.createLast(
                fixture.record(seconds: 60, luid: "other".luid, mac: "unrelated".mac))
            let last = expectation(description: "Most recent history")
            let latest = expectation(description: "Latest live value")
            let lastToken = fixture.reactor.observeLast(sensor) { change in
                guard case .update(let record) = change else { return XCTFail("Expected a value") }
                XCTAssertEqual(record?.date, fixture.date.addingTimeInterval(20))
                last.fulfill()
            }
            let latestToken = fixture.reactor.observeLatest(sensor) { change in
                guard case .update(let record) = change else { return XCTFail("Expected a value") }
                XCTAssertEqual(record?.date, fixture.date.addingTimeInterval(30))
                latest.fulfill()
            }
            await fulfillment(of: [last, latest], timeout: 3)
            lastToken.invalidate()
            latestToken.invalidate()
        }
    }

    func testAbsentIdentityCannotObserveAnotherSensorsMeasurements() async throws {
        let fixture = try ReactorDatabaseFixture()
        defer { fixture.close() }
        _ = try await fixture.store.create(fixture.record(seconds: 10))
        _ = try await fixture.store.createLast(fixture.record(seconds: 20))
        let sensor = fixture.sensor(luid: nil, mac: nil)
        let last = expectation(description: "No history for unknown sensor")
        let latest = expectation(description: "No latest value for unknown sensor")
        let lastToken = fixture.reactor.observeLast(sensor) { change in
            guard case .update(let value) = change else { return XCTFail("Expected optional value") }
            XCTAssertNil(value)
            last.fulfill()
        }
        let latestToken = fixture.reactor.observeLatest(sensor) { change in
            guard case .update(let value) = change else { return XCTFail("Expected optional value") }
            XCTAssertNil(value)
            latest.fulfill()
        }
        await fulfillment(of: [last, latest], timeout: 3)
        lastToken.invalidate()
        latestToken.invalidate()
    }

    func testSettingsObservationDeliversInitialInsertUpdateAndDeleteWithoutOtherSensors() async throws {
        let fixture = try ReactorDatabaseFixture()
        defer { fixture.close() }
        let sensor = fixture.sensor(luid: fixture.luid, mac: fixture.mac)
        let initial = expectation(description: "No settings")
        let inserted = expectation(description: "Settings inserted")
        let updated = expectation(description: "Settings updated")
        let deleted = expectation(description: "Settings deleted")
        var events = [String]()
        let token = fixture.reactor.observe(sensor) { change in
            XCTAssertTrue(Thread.isMainThread)
            switch change {
            case .initial(let values):
                XCTAssertTrue(values.isEmpty); events.append("initial"); initial.fulfill()
            case .insert(let value):
                XCTAssertEqual(value.description, "first"); events.append("insert"); inserted.fulfill()
            case .update(let value):
                XCTAssertEqual(value.description, "second"); events.append("update"); updated.fulfill()
            case .delete(let value):
                XCTAssertEqual(value.description, "second"); events.append("delete"); deleted.fulfill()
            case .error(let error): XCTFail("Unexpected settings error: \(error)")
            }
        }
        defer { token.invalidate() }
        await fulfillment(of: [initial], timeout: 3)
        _ = try await fixture.store.updateDescription(
            for: fixture.sensor(luid: "other".luid, mac: "11:22:33:44:55:66".mac),
            description: "unrelated", descriptionLastUpdated: fixture.date)
        _ = try await fixture.store.updateDescription(
            for: sensor, description: "first", descriptionLastUpdated: fixture.date)
        await fulfillment(of: [inserted], timeout: 3)
        _ = try await fixture.store.updateDescription(
            for: sensor, description: "second", descriptionLastUpdated: fixture.date.addingTimeInterval(1))
        await fulfillment(of: [updated], timeout: 3)
        _ = try await fixture.store.deleteSensorSettings(sensor)
        await fulfillment(of: [deleted], timeout: 3)
        XCTAssertEqual(events, ["initial", "insert", "update", "delete"])
    }

    func testMissingDatabaseTablesDeliverTypedErrorsAndHistoryReportsThroughAnalytics() async throws {
        let fixture = try ReactorDatabaseFixture()
        defer { fixture.close() }
        try await fixture.context.database.dbPool.write { database in
            for table in [
                "ruuvi_tag_sensors", "ruuvi_tag_sensor_records", "ruuvi_tag_sensor_record_latest", "sensor_settings",
            ] {
                try database.execute(sql: "DROP TABLE \(table)")
            }
        }
        let failures = expectation(description: "All failed subscriptions report")
        failures.expectedFulfillmentCount = 5
        func verify(_ error: RuuviReactorError) {
            XCTAssertTrue(Thread.isMainThread)
            guard case .ruuviPersistence(.grdb) = error else { return XCTFail("Error lost its database context") }
            failures.fulfill()
        }
        fixture.reporter.onError = { error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(error is DatabaseError)
            failures.fulfill()
        }
        let sensor = fixture.sensor(luid: fixture.luid, mac: fixture.mac)
        let tokens = [
            fixture.reactor.observe { change in
                guard case .error(let error) = change else { return XCTFail("Expected sensor error") }
                verify(error)
            },
            fixture.reactor.observe(fixture.luid) { _ in XCTFail("Failed history must not publish a snapshot") },
            fixture.reactor.observeLast(sensor) { change in
                guard case .error(let error) = change else { return XCTFail("Expected history error") }
                verify(error)
            },
            fixture.reactor.observeLatest(sensor) { change in
                guard case .error(let error) = change else { return XCTFail("Expected latest value error") }
                verify(error)
            },
            fixture.reactor.observe(sensor) { change in
                guard case .error(let error) = change else { return XCTFail("Expected settings error") }
                verify(error)
            },
        ]
        await fulfillment(of: [failures], timeout: 3)
        tokens.forEach { $0.invalidate() }
    }
}

private final class ReactorDatabaseFixture {
    let directory: URL
    let context: SQLiteContext
    let store: RuuviPersistenceSQLite
    let reactor: RuuviReactor
    let reporter = ObservationErrorReporter()
    let luid = UUID().uuidString.luid
    let mac = "AA:BB:CC:DD:EE:FF".mac
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("reactor.sqlite"))
        store = RuuviPersistenceSQLite(context: context)
        reactor = RuuviReactorFactoryImpl().create(
            sqliteContext: context, sqlitePersistence: store, errorReporter: reporter)
    }

    func close() {
        try? context.database.dbPool.close()
        try? FileManager.default.removeItem(at: directory)
    }

    func sensor(luid: LocalIdentifier?, mac: MACIdentifier?) -> RuuviTagSensorStruct {
        .init(
            version: 5, firmwareVersion: nil, luid: luid, macId: mac, serviceUUID: nil,
            isConnectable: false, name: "Room", isClaimed: false, isOwner: true, owner: nil,
            ownersPlan: nil, isCloudSensor: false, canShare: false, sharedTo: [], maxHistoryDays: nil)
    }

    func record(seconds: Double, luid: LocalIdentifier? = nil, mac: MACIdentifier? = nil) -> RuuviTagSensorRecordStruct
    {
        .init(
            luid: luid ?? self.luid, date: date.addingTimeInterval(seconds), source: .advertisement,
            macId: mac ?? self.mac, rssi: nil, version: 5,
            temperature: .init(value: seconds, unit: .celsius), humidity: nil, pressure: nil,
            acceleration: nil, voltage: nil, movementCounter: nil, measurementSequenceNumber: nil,
            txPower: nil, pm1: nil, pm25: nil, pm4: nil, pm10: nil, co2: nil, voc: nil, nox: nil,
            luminance: nil, dbaInstant: nil, dbaAvg: nil, dbaPeak: nil,
            temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0)
    }
}

private final class ObservationErrorReporter: RuuviErrorReporter {
    var onError: ((Error) -> Void)?
    func report(error: Error) {
        guard let onError else { return XCTFail("Unexpected database failure: \(error)") }
        onError(error)
    }
}
