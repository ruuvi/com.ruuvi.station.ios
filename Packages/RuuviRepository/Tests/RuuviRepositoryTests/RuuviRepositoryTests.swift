import Foundation
import Testing
import GRDB
import RuuviContext
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviStorage
@testable import RuuviRepository
#if SWIFT_PACKAGE
    import RuuviContextSQLite
    import RuuviLocalUserDefaults
    import RuuviPersistenceSQLite
    import RuuviPoolCoordinator
    import RuuviStorageCoordinator
    import RuuviRepositoryCoordinator
#endif

@MainActor struct RuuviRepositoryTests {
    @Test func sensorLifecycleAndCountsAreDurable() async throws {
        let fixture = try RepositoryFixture()
        defer { fixture.close() }
        var sensor = fixture.sensor
        #expect(try await fixture.storage.readAll().isEmpty)
        #expect(try await fixture.pool.create(sensor))
        #expect(try await fixture.storage.getStoredTagsCount() == 1)
        #expect(try await fixture.storage.getClaimedTagsCount() == 1)
        #expect(try await fixture.storage.getOfflineTagsCount() == 1)
        sensor.name = "Renamed"; sensor.isCloudSensor = true
        #expect(try await fixture.pool.update(sensor))
        #expect(try await fixture.storage.readOne(sensor.id).name == "Renamed")
        #expect(try await fixture.storage.readOne(sensor.luid!.value).macId?.value == sensor.macId?.value)
        #expect(try await fixture.storage.getOfflineTagsCount() == 0)
        #expect(try await fixture.pool.delete(sensor))
        #expect(try await fixture.storage.readAll().isEmpty)
        do {
            _ = try await fixture.storage.readOne(sensor.id)
            Issue.record("Deleted sensor remained readable")
        } catch {
            guard case .ruuviPersistence(.failedToFindRuuviTag) = error else {
                Issue.record("Unexpected missing-sensor error: \(error)"); return
            }
        }
    }

    @Test func repositoryWritesHistoryBeforeReturningAndQueriesRespectDateBounds() async throws {
        let fixture = try RepositoryFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        let records = (0..<4).map { fixture.record(seconds: $0 * 60) }
        let first = try await fixture.repository.create(record: records[0], for: fixture.sensor)
        #expect(first.id == records[0].id)
        let saved = try await fixture.repository.create(records: Array(records.dropFirst()), for: fixture.sensor)
        #expect(saved.map(\.id) == records.dropFirst().map(\.id))
        #expect(try await fixture.storage.getStoredMeasurementsCount() == 4)
        let all = try await fixture.storage.readAll(fixture.sensor.id)
        #expect(all.map(\.date) == records.map(\.date))
        #expect(all.map { $0.temperature?.value } == [20, 20, 20, 20])
        let after = try await fixture.storage.readAll(fixture.sensor.id, after: records[1].date)
        #expect(after.map(\.date) == records.suffix(2).map(\.date))
        let last = try await fixture.storage.readLast(fixture.sensor.id, from: records[1].date.timeIntervalSince1970)
        #expect(last.map(\.date) == after.map(\.date))
        #expect(try await fixture.storage.readLast(fixture.sensor)?.date == records.last?.date)
        let sampled = try await fixture.storage.read(fixture.sensor.id, after: records[0].date, with: 60)
        #expect(sampled.map(\.date) == records.dropFirst().map(\.date))
        #expect(try await fixture.storage.readAll(fixture.sensor.id, with: 60).count == 4)
        let downsampled = try await fixture.storage.readDownsampled(
            fixture.sensor.id, after: records[0].date.addingTimeInterval(-1), with: 5, pick: 10)
        #expect(downsampled.count == 4)
        try await fixture.pool.deleteAllRecords(fixture.sensor.id, before: records[2].date)
        #expect(try await fixture.storage.readAll(fixture.sensor.id).map(\.date) == records.suffix(2).map(\.date))
        try await fixture.pool.deleteAllRecords(fixture.sensor.id)
        #expect(try await fixture.storage.readAll(fixture.sensor.id).isEmpty)
        #expect(try await fixture.pool.cleanupDBSpace())
    }

    @Test func latestMeasurementIsSeparateFromHistoryAndCanBeReplacedAndDeleted() async throws {
        let fixture = try RepositoryFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        #expect(try await fixture.storage.readLatest(fixture.sensor) == nil)
        try await fixture.pool.createLast(fixture.record(seconds: 0))
        #expect(try await fixture.storage.readLatest(fixture.sensor)?.date == fixture.record(seconds: 0).date)
        #expect(try await fixture.storage.readAll(fixture.sensor.id).isEmpty)
        try await fixture.pool.updateLast(fixture.record(seconds: 60))
        #expect(try await fixture.storage.readLatest(fixture.sensor)?.date == fixture.record(seconds: 60).date)
        try await fixture.pool.deleteLast(fixture.sensor.id)
        #expect(try await fixture.storage.readLatest(fixture.sensor) == nil)
    }

    @Test func individualAndBatchBluetoothRecordsResolveTheirLocalIdentity() async throws {
        let fixture = try RepositoryFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        var first = fixture.record(seconds: 0); first.macId = nil
        var second = fixture.record(seconds: 60); second.macId = nil
        try await fixture.pool.create(first)
        try await fixture.pool.create([second])
        let stored = try await fixture.storage.readAll(fixture.sensor.id)
        #expect(stored.count == 2)
        #expect(stored.allSatisfy { $0.macId?.value == fixture.sensor.macId?.value })
        try await fixture.pool.createLast(first)
        try await fixture.pool.updateLast(second)
        #expect(try await fixture.storage.readLatest(fixture.sensor)?.date == second.date)
    }

    @Test func unresolvableBatchFailsWithoutWritingOrSilentlyDroppingMeasurements() async throws {
        let fixture = try RepositoryFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        var unknown = fixture.record(seconds: 60)
        unknown.macId = nil; unknown.luid = UUID().uuidString.luid
        do {
            _ = try await fixture.repository.create(
                records: [fixture.record(seconds: 0), unknown], for: fixture.sensor)
            Issue.record("Unresolvable measurement must fail the batch")
        } catch {
            guard case .ruuviPool(.ruuviPersistence(.failedToFindRuuviTag)) = error else {
                Issue.record("Unexpected repository error: \(error)"); return
            }
        }
        #expect(try await fixture.storage.getStoredMeasurementsCount() == 0)
        do {
            _ = try await fixture.repository.create(record: unknown, for: fixture.sensor)
            Issue.record("Unresolvable individual measurement must fail")
        } catch {
            guard case .ruuviPool(.ruuviPersistence(.failedToFindRuuviTag)) = error else {
                Issue.record("Unexpected repository error: \(error)"); return
            }
        }
    }

    @Test func calibrationDescriptionAndDisplayUpdatesPreserveEachOther() async throws {
        let fixture = try RepositoryFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        #expect(try await fixture.storage.readSensorSettings(fixture.sensor) == nil)
        let timestamp = Date(timeIntervalSince1970: 123456)
        _ = try await fixture.pool.updateOffsetCorrection(
            type: .temperature, with: 1.5, of: fixture.sensor,
            lastOriginalRecord: fixture.record(seconds: 0))
        _ = try await fixture.pool.updateOffsetCorrection(type: .humidity, with: 2, of: fixture.sensor)
        _ = try await fixture.pool.updateOffsetCorrection(type: .pressure, with: -3, of: fixture.sensor)
        _ = try await fixture.pool.updateDisplaySettings(
            for: fixture.sensor, displayOrder: ["humidity", "temperature"],
            defaultDisplayOrder: false, displayOrderLastUpdated: timestamp, defaultDisplayOrderLastUpdated: timestamp)
        _ = try await fixture.pool.updateDescription(
            for: fixture.sensor, description: "Greenhouse 🌿",
            descriptionLastUpdated: timestamp)
        let settings = try #require(try await fixture.pool.readSensorSettings(fixture.sensor))
        #expect(settings.temperatureOffset == 1.5)
        #expect(settings.humidityOffset == 2)
        #expect(settings.pressureOffset == -3)
        #expect(settings.displayOrder == ["humidity", "temperature"])
        #expect(settings.defaultDisplayOrder == false)
        #expect(settings.displayOrderLastUpdated == timestamp)
        #expect(settings.description == "Greenhouse 🌿")
        #expect(settings.descriptionLastUpdated == timestamp)
        #expect(try await fixture.storage.getStoredMeasurementsCount() == 1)
        _ = try await fixture.pool.updateOffsetCorrection(type: .temperature, with: nil, of: fixture.sensor)
        #expect(try await fixture.storage.readSensorSettings(fixture.sensor)?.temperatureOffset == nil)
        try await fixture.pool.deleteSensorSettings(fixture.sensor)
        #expect(try await fixture.storage.readSensorSettings(fixture.sensor) == nil)
    }

    @Test func userSettingsAndQueueFilterThroughStorageAndPool() async throws {
        let fixture = try RepositoryFixture()
        defer { fixture.close() }
        _ = try await fixture.storage.save(userSetting: RuuviUserSettingStruct(key: "a", value: "first"))
        _ = try await fixture.storage.save(userSettings: [
            RuuviUserSettingStruct(key: "a", value: "second"),
            RuuviUserSettingStruct(key: "b", value: "other"),
        ])
        #expect(try await fixture.storage.readUserSetting(for: "a")?.value == "second")
        #expect(try await fixture.storage.readUserSettings().count == 2)
        try await fixture.pool.deleteUserSettings()
        #expect(try await fixture.storage.readUserSettings().isEmpty)
        for key in ["a", "b"] {
            try await fixture.pool.createQueuedRequest(
                RuuviCloudQueuedRequestStruct(
                    id: nil, type: .settings, status: .failed, uniqueKey: key, requestDate: Date(), successDate: nil,
                    attempts: 0, requestBodyData: Data(), additionalData: nil))
        }
        let requests = try await fixture.storage.readQueuedRequests()
        #expect(requests.count == 2)
        #expect(try await fixture.storage.readQueuedRequests(for: "a").count == 1)
        #expect(try await fixture.storage.readQueuedRequests(for: .settings).count == 2)
        try await fixture.pool.deleteQueuedRequest(try #require(requests.first))
        #expect(try await fixture.storage.readQueuedRequests().count == 1)
        try await fixture.pool.deleteQueuedRequests()
        #expect(try await fixture.storage.readQueuedRequests().isEmpty)
    }
}

@MainActor private struct RepositoryFixture {
    let directory: URL
    let persistence: RuuviPersistenceSQLite
    let pool: RuuviPool
    let storage: RuuviStorage
    let repository: RuuviRepository
    let sensor: RuuviTagSensorStruct
    let date = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970 / 60) * 60 - 600)
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("repository.sqlite"))
        persistence = RuuviPersistenceSQLite(context: context)
        let local = RuuviLocalFactoryUserDefaults()
        pool = RuuviPoolFactoryCoordinator().create(
            sqlite: persistence, idPersistence: local.createLocalIDs(),
            settings: local.createLocalSettings(), connectionPersistence: local.createLocalConnections())
        storage = RuuviStorageFactoryCoordinator().create(sqlite: persistence)
        repository = RuuviRepositoryFactoryCoordinator().create(pool: pool, storage: storage)
        sensor = RuuviTagSensorStruct(
            version: 5, firmwareVersion: nil, luid: UUID().uuidString.luid,
            macId: "CA:FE:00:01:02:03".mac, serviceUUID: nil, isConnectable: true, name: "Sensor",
            isClaimed: true, isOwner: true, owner: nil, ownersPlan: nil, isCloudSensor: false,
            canShare: false, sharedTo: [], maxHistoryDays: nil)
    }
    func record(seconds: Int) -> RuuviTagSensorRecordStruct {
        RuuviTagSensorRecordStruct(
            luid: sensor.luid, date: date.addingTimeInterval(Double(seconds)),
            source: .log, macId: sensor.macId, rssi: -55, version: 5,
            temperature: .init(value: 20, unit: .celsius), humidity: nil, pressure: nil,
            acceleration: nil, voltage: nil, movementCounter: nil, measurementSequenceNumber: nil, txPower: nil,
            pm1: nil, pm25: nil, pm4: nil, pm10: nil, co2: nil, voc: nil, nox: nil, luminance: nil,
            dbaInstant: nil, dbaAvg: nil, dbaPeak: nil, temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0)
    }
    func close() {
        try? persistence.database.dbPool.close()
        try? FileManager.default.removeItem(at: directory)
    }
}
