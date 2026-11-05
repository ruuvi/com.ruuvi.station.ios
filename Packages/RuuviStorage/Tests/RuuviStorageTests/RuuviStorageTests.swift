import Foundation
import GRDB
import RuuviContext
import RuuviOntology
import RuuviPersistence
import RuuviStorage
#if SWIFT_PACKAGE
    import RuuviContextSQLite
    import RuuviPersistenceSQLite
    import RuuviStorageCoordinator
#endif
import XCTest

@MainActor final class RuuviStorageTests: XCTestCase {
    func testSensorCountsDistinguishClaimedOwnedAndOfflineSensors() async throws {
        let fixture = try StorageDatabaseFixture()
        defer { fixture.close() }
        let empty = try await fixture.storage.readAll()
        XCTAssertTrue(empty.isEmpty)
        for (mac, claimed, owner, cloud) in [
            ("AA:BB:CC:DD:EE:01", true, true, true),
            ("AA:BB:CC:DD:EE:02", true, false, true),
            ("AA:BB:CC:DD:EE:03", false, true, false),
        ] {
            _ = try await fixture.persistence.create(
                fixture.sensor(mac: mac, claimed: claimed, owner: owner, cloud: cloud))
        }
        let total = try await fixture.storage.getStoredTagsCount()
        let claimed = try await fixture.storage.getClaimedTagsCount()
        let offline = try await fixture.storage.getOfflineTagsCount()
        XCTAssertEqual(total, 3)
        XCTAssertEqual(claimed, 1)
        XCTAssertEqual(offline, 1)
        let sensor = try await fixture.storage.readOne("AA:BB:CC:DD:EE:02")
        XCTAssertFalse(sensor.isOwner)
        do {
            _ = try await fixture.storage.readOne("not-stored")
            XCTFail("A missing sensor must not be returned")
        } catch {
            guard case .ruuviPersistence(.failedToFindRuuviTag) = error else { return XCTFail("Wrong error: \(error)") }
        }
    }

    func testLocalIdentifierCanRetrieveHistoryLatestAndSettingsBeforeMACIsKnown() async throws {
        let fixture = try StorageDatabaseFixture()
        defer { fixture.close() }
        let fullSensor = fixture.sensor()
        _ = try await fixture.persistence.create(fullSensor)
        let record = fixture.record()
        _ = try await fixture.persistence.create(record)
        _ = try await fixture.persistence.createLast(record)
        _ = try await fixture.persistence.updateDescription(
            for: fullSensor, description: "Living room", descriptionLastUpdated: fixture.date)
        var localSensor = fullSensor
        localSensor.macId = nil
        let history = try await fixture.storage.readLast(localSensor)
        let latest = try await fixture.storage.readLatest(localSensor)
        let settings = try await fixture.storage.readSensorSettings(localSensor)
        XCTAssertEqual(history?.date, fixture.date)
        XCTAssertEqual(latest?.temperature?.value, 21)
        XCTAssertEqual(settings?.description, "Living room")
    }

    func testMissingSensorIdentityFailsWithoutReturningUnrelatedData() async throws {
        let fixture = try StorageDatabaseFixture()
        defer { fixture.close() }
        var unidentified = fixture.sensor()
        unidentified.luid = nil
        unidentified.macId = nil
        let operations: [() async throws -> Void] = [
            { _ = try await fixture.storage.readLast(unidentified) },
            { _ = try await fixture.storage.readLatest(unidentified) },
            { _ = try await fixture.storage.readSensorSettings(unidentified) },
        ]
        for operation in operations {
            do {
                try await operation()
                XCTFail("Expected identity failure")
            } catch {
                guard let error = error as? RuuviStorageError,
                    case .ruuviPersistence(.failedToFindRuuviTag) = error
                else { return XCTFail("Wrong identity error: \(error)") }
            }
        }
    }

    func testClosedDatabaseErrorsRetainTheirCauseAcrossEveryStorageOperation() async throws {
        let fixture = try StorageDatabaseFixture()
        defer { fixture.close() }
        try fixture.context.database.dbPool.close()
        let store = fixture.storage
        let sensor = fixture.sensor()
        let setting = RuuviUserSettingStruct(key: "language", value: "en")
        let operations: [(String, () async throws -> Void)] = [
            ("sensor", { _ = try await store.readOne(sensor.id) }),
            ("sensors", { _ = try await store.readAll() }),
            ("history", { _ = try await store.readAll(sensor.id) }),
            ("history after", { _ = try await store.readAll(sensor.id, after: fixture.date) }),
            ("sampled history", { _ = try await store.read(sensor.id, after: fixture.date, with: 60) }),
            (
                "downsampled history",
                { _ = try await store.readDownsampled(sensor.id, after: fixture.date, with: 1, pick: 2) }
            ),
            ("history interval", { _ = try await store.readAll(sensor.id, with: 60) }),
            ("recent history", { _ = try await store.readLast(sensor.id, from: fixture.date.timeIntervalSince1970) }),
            ("last", { _ = try await store.readLast(sensor) }),
            ("latest", { _ = try await store.readLatest(sensor) }),
            ("sensor count", { _ = try await store.getStoredTagsCount() }),
            ("claimed count", { _ = try await store.getClaimedTagsCount() }),
            ("offline count", { _ = try await store.getOfflineTagsCount() }),
            ("measurement count", { _ = try await store.getStoredMeasurementsCount() }),
            ("sensor settings", { _ = try await store.readSensorSettings(sensor) }),
            ("queued requests", { _ = try await store.readQueuedRequests() }),
            ("queued sensor requests", { _ = try await store.readQueuedRequests(for: sensor.id) }),
            ("queued settings requests", { _ = try await store.readQueuedRequests(for: .settings) }),
            ("user settings", { _ = try await store.readUserSettings() }),
            ("user setting", { _ = try await store.readUserSetting(for: setting.key) }),
            ("save user setting", { _ = try await store.save(userSetting: setting) }),
            ("save user settings", { _ = try await store.save(userSettings: [setting]) }),
        ]
        for (name, operation) in operations {
            do {
                try await operation()
                XCTFail("Closed database incorrectly succeeded: \(name)")
            } catch {
                guard let error = error as? RuuviStorageError,
                    case .ruuviPersistence(.grdb(let cause)) = error
                else { XCTFail("Lost database error in \(name): \(error)"); continue }
                XCTAssertTrue(cause is DatabaseError, name)
            }
        }
    }
}

private final class StorageDatabaseFixture {
    let directory: URL
    let context: SQLiteContext
    let persistence: RuuviPersistenceSQLite
    let storage: RuuviStorage
    let luid = UUID().uuidString.luid
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("storage.sqlite"))
        persistence = RuuviPersistenceSQLite(context: context)
        storage = RuuviStorageFactoryCoordinator().create(sqlite: persistence)
    }

    func close() {
        try? context.database.dbPool.close()
        try? FileManager.default.removeItem(at: directory)
    }

    func sensor(mac: String = "AA:BB:CC:DD:EE:FF", claimed: Bool = false, owner: Bool = true, cloud: Bool = false)
        -> RuuviTagSensorStruct
    {
        .init(
            version: 5, firmwareVersion: nil, luid: luid, macId: mac.mac, serviceUUID: nil,
            isConnectable: false, name: "Room", isClaimed: claimed, isOwner: owner, owner: nil,
            ownersPlan: nil, isCloudSensor: cloud, canShare: false, sharedTo: [], maxHistoryDays: nil)
    }

    func record() -> RuuviTagSensorRecordStruct {
        .init(
            luid: luid, date: date, source: .advertisement, macId: "AA:BB:CC:DD:EE:FF".mac,
            rssi: nil, version: 5, temperature: .init(value: 21, unit: .celsius), humidity: nil,
            pressure: nil, acceleration: nil, voltage: nil, movementCounter: nil, measurementSequenceNumber: nil,
            txPower: nil, pm1: nil, pm25: nil, pm4: nil, pm10: nil, co2: nil, voc: nil, nox: nil,
            luminance: nil, dbaInstant: nil, dbaAvg: nil, dbaPeak: nil,
            temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0)
    }
}
