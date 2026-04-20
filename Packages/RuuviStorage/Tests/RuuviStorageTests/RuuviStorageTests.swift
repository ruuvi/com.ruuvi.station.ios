@testable import RuuviStorage
import RuuviOntology
import RuuviPersistence
import XCTest

final class RuuviStorageTests: XCTestCase {
    func testReadDelegatesAllRecordVariantsToPersistence() async throws {
        let sqlite = PersistenceSpy()
        let record = makeRecord()
        let sensor = makeSensor().any
        sqlite.readOneResult = sensor
        sqlite.recordsResult = [record]
        sqlite.downsampledResult = [record]
        let sut = RuuviStorageCoordinator(sqlite: sqlite)
        let date = Date(timeIntervalSince1970: 1234)

        let one = try await sut.readOne(sensor.id)
        let all = try await sut.readAll(sensor.id)
        let after = try await sut.readAll(sensor.id, after: date)
        let interval = try await sut.read(sensor.id, after: date, with: 60)
        let downsampled = try await sut.readDownsampled(sensor.id, after: date, with: 15, pick: 500)
        let allInterval = try await sut.readAll(sensor.id, with: 30)
        let last = try await sut.readLast(sensor.id, from: 120)

        XCTAssertEqual(one.id, sensor.id)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(interval.count, 1)
        XCTAssertEqual(downsampled.count, 1)
        XCTAssertEqual(allInterval.count, 1)
        XCTAssertEqual(last.count, 1)
        XCTAssertEqual(sqlite.readOneIDs, [sensor.id])
        XCTAssertEqual(sqlite.readAllIDs, [sensor.id])
        XCTAssertEqual(sqlite.readAllAfterCalls.first?.0, sensor.id)
        XCTAssertEqual(sqlite.readCalls.first?.0, sensor.id)
        XCTAssertEqual(sqlite.readDownsampledCalls.first?.0, sensor.id)
        XCTAssertEqual(sqlite.readAllIntervalCalls.first?.0, sensor.id)
        XCTAssertEqual(sqlite.readLastCalls.first?.0, sensor.id)
    }

    func testGetClaimedTagsCountCountsOnlyClaimedOwnedSensors() async throws {
        let sqlite = PersistenceSpy()
        sqlite.readAllResult = [
            makeSensor(macId: "AA:BB:CC:11:22:33", isClaimed: true, isOwner: true, isCloud: true).any,
            makeSensor(macId: "AA:BB:CC:44:55:66", isClaimed: true, isOwner: false, isCloud: true).any,
            makeSensor(macId: "AA:BB:CC:77:88:99", isClaimed: false, isOwner: true, isCloud: false).any,
        ]
        let sut = RuuviStorageCoordinator(sqlite: sqlite)

        let count = try await sut.getClaimedTagsCount()

        XCTAssertEqual(count, 1)
    }

    func testGetOfflineTagsCountCountsNonCloudSensors() async throws {
        let sqlite = PersistenceSpy()
        sqlite.readAllResult = [
            makeSensor(macId: "AA:BB:CC:11:22:33", isClaimed: true, isOwner: true, isCloud: true).any,
            makeSensor(macId: "AA:BB:CC:44:55:66", isClaimed: false, isOwner: false, isCloud: false).any,
            makeSensor(macId: "AA:BB:CC:77:88:99", isClaimed: false, isOwner: true, isCloud: false).any,
        ]
        let sut = RuuviStorageCoordinator(sqlite: sqlite)

        let count = try await sut.getOfflineTagsCount()

        XCTAssertEqual(count, 2)
    }

    func testReadLatestSettingsAndQueuedRequestsDelegateToPersistence() async throws {
        let sqlite = PersistenceSpy()
        let sensor = makeSensor()
        let record = makeRecord()
        let expectedKey = "request-1"
        let expectedType = RuuviCloudQueuedRequestType.sensor
        let request = makeRequest(type: expectedType, uniqueKey: expectedKey)
        let settings = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: 1,
            humidityOffset: 2,
            pressureOffset: 3
        )
        sqlite.lastRecordResult = record
        sqlite.latestRecordResult = record
        sqlite.sensorSettingsResult = settings
        sqlite.queuedRequestsResult = [request]
        sqlite.queuedRequestsForKeyResult = [request]
        sqlite.queuedRequestsForTypeResult = [request]
        sqlite.storedMeasurementsCount = 42
        let sut = RuuviStorageCoordinator(sqlite: sqlite)

        let last = try await sut.readLast(sensor)
        let latest = try await sut.readLatest(sensor)
        let loadedSettings = try await sut.readSensorSettings(sensor)
        let allRequests = try await sut.readQueuedRequests()
        let keyedRequests = try await sut.readQueuedRequests(for: expectedKey)
        let typedRequests = try await sut.readQueuedRequests(for: expectedType)
        let measurementsCount = try await sut.getStoredMeasurementsCount()

        XCTAssertEqual(last?.id, record.id)
        XCTAssertEqual(latest?.id, record.id)
        XCTAssertEqual(loadedSettings?.temperatureOffset, 1)
        XCTAssertEqual(allRequests.count, 1)
        XCTAssertEqual(keyedRequests.first?.uniqueKey, expectedKey)
        XCTAssertEqual(typedRequests.first?.type, expectedType)
        XCTAssertEqual(measurementsCount, 42)
        XCTAssertEqual(sqlite.readLastSensors.map(\.id), [sensor.id])
        XCTAssertEqual(sqlite.readLatestSensors.map(\.id), [sensor.id])
        XCTAssertEqual(sqlite.readSensorSettingsSensors.map(\.id), [sensor.id])
        XCTAssertEqual(sqlite.readQueuedRequestsKeys, [expectedKey])
        XCTAssertEqual(sqlite.readQueuedRequestsTypes, [expectedType])
    }

    func testMacBackedReadsReturnNilWithoutPersistenceWhenSensorHasNoMac() async throws {
        let sqlite = PersistenceSpy()
        let sensor = makeSensor(macId: nil)
        let sut = RuuviStorageCoordinator(sqlite: sqlite)

        let last = try await sut.readLast(sensor)
        let latest = try await sut.readLatest(sensor)
        let settings = try await sut.readSensorSettings(sensor)

        XCTAssertNil(last)
        XCTAssertNil(latest)
        XCTAssertNil(settings)
        XCTAssertTrue(sqlite.readLastSensors.isEmpty)
        XCTAssertTrue(sqlite.readLatestSensors.isEmpty)
        XCTAssertTrue(sqlite.readSensorSettingsSensors.isEmpty)
    }

    func testReadOneAndStoredTagCountDelegateToPersistence() async throws {
        let sqlite = PersistenceSpy()
        let sensor = makeSensor().any
        sqlite.readOneResult = sensor
        sqlite.readAllResult = [sensor]
        sqlite.storedTagsCount = 7
        let sut = RuuviStorageCoordinator(sqlite: sqlite)

        let loaded = try await sut.readOne(sensor.id)
        let all = try await sut.readAll()
        let count = try await sut.getStoredTagsCount()

        XCTAssertEqual(loaded.id, sensor.id)
        XCTAssertEqual(all.map(\.id), [sensor.id])
        XCTAssertEqual(count, 7)
        XCTAssertEqual(sqlite.readOneIDs, [sensor.id])
    }

    func testReadAllWrapsUnexpectedPersistenceErrors() async {
        let sqlite = PersistenceSpy()
        sqlite.readAllError = DummyError()
        let sut = RuuviStorageCoordinator(sqlite: sqlite)

        do {
            _ = try await sut.readAll()
            XCTFail("Expected storage error")
        } catch let error as RuuviStorageError {
            guard case let .ruuviPersistence(persistenceError) = error else {
                return XCTFail("Expected wrapped persistence error")
            }
            guard case .grdb = persistenceError else {
                return XCTFail("Expected GRDB wrapped error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStorageOperationPassesThroughStorageErrorsAndWrapsPersistenceErrors() async {
        let storageErrorSQLite = PersistenceSpy()
        storageErrorSQLite.readAllError = RuuviStorageError.ruuviPersistence(.failedToFindRuuviTag)
        let storageErrorSUT = RuuviStorageCoordinator(sqlite: storageErrorSQLite)

        do {
            _ = try await storageErrorSUT.readAll()
            XCTFail("Expected storage error")
        } catch let error as RuuviStorageError {
            guard case .ruuviPersistence(.failedToFindRuuviTag) = error else {
                return XCTFail("Expected direct storage error passthrough")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let persistenceErrorSQLite = PersistenceSpy()
        persistenceErrorSQLite.readAllError = RuuviPersistenceError.failedToFindRuuviTag
        let persistenceErrorSUT = RuuviStorageCoordinator(sqlite: persistenceErrorSQLite)

        do {
            _ = try await persistenceErrorSUT.readAll()
            XCTFail("Expected persistence error")
        } catch let error as RuuviStorageError {
            guard case .ruuviPersistence(.failedToFindRuuviTag) = error else {
                return XCTFail("Expected wrapped persistence error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFactoryCreatesCoordinatorBackedStorage() {
        let sqlite = PersistenceSpy()
        let sut = RuuviStorageFactoryCoordinator()

        let storage = sut.create(sqlite: sqlite)

        XCTAssertTrue(storage is RuuviStorageCoordinator)
    }
}

private final class PersistenceSpy: RuuviPersistence {
    var readAllResult: [AnyRuuviTagSensor] = []
    var readAllError: Error?
    var readOneResult: AnyRuuviTagSensor = makeSensor().any
    var recordsResult: [RuuviTagSensorRecord] = []
    var downsampledResult: [RuuviTagSensorRecord] = []
    var lastRecordResult: RuuviTagSensorRecord?
    var latestRecordResult: RuuviTagSensorRecord?
    var sensorSettingsResult: SensorSettings?
    var queuedRequestsResult: [RuuviCloudQueuedRequest] = []
    var queuedRequestsForKeyResult: [RuuviCloudQueuedRequest] = []
    var queuedRequestsForTypeResult: [RuuviCloudQueuedRequest] = []
    var storedTagsCount = 0
    var storedMeasurementsCount = 0
    var readOneIDs: [String] = []
    var readAllIDs: [String] = []
    var readAllAfterCalls: [(String, Date)] = []
    var readCalls: [(String, Date, TimeInterval)] = []
    var readDownsampledCalls: [(String, Date, Int, Double)] = []
    var readAllIntervalCalls: [(String, TimeInterval)] = []
    var readLastCalls: [(String, TimeInterval)] = []
    var readLastSensors: [AnyRuuviTagSensor] = []
    var readLatestSensors: [AnyRuuviTagSensor] = []
    var readSensorSettingsSensors: [AnyRuuviTagSensor] = []
    var readQueuedRequestsKeys: [String] = []
    var readQueuedRequestsTypes: [RuuviCloudQueuedRequestType] = []

    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool { true }
    func create(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool { true }

    func readAll() async throws -> [AnyRuuviTagSensor] {
        if let readAllError {
            throw readAllError
        }
        return readAllResult
    }

    func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord] {
        readAllIDs.append(ruuviTagId)
        return recordsResult
    }

    func readAll(_ ruuviTagId: String, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        readAllIntervalCalls.append((ruuviTagId, interval))
        return recordsResult
    }

    func readAll(_ ruuviTagId: String, after date: Date) async throws -> [RuuviTagSensorRecord] {
        readAllAfterCalls.append((ruuviTagId, date))
        return recordsResult
    }

    func readLast(_ ruuviTagId: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        readLastCalls.append((ruuviTagId, from))
        return recordsResult
    }

    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        readLastSensors.append(ruuviTag.any)
        return lastRecordResult
    }

    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        readLatestSensors.append(ruuviTag.any)
        return latestRecordResult
    }

    func deleteLatest(_ ruuviTagId: String) async throws -> Bool { true }
    func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor {
        readOneIDs.append(ruuviTagId)
        return readOneResult
    }

    func getStoredTagsCount() async throws -> Int { storedTagsCount }
    func getStoredMeasurementsCount() async throws -> Int { storedMeasurementsCount }

    func read(_ ruuviTagId: String, after date: Date, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        readCalls.append((ruuviTagId, date, interval))
        return recordsResult
    }

    func readDownsampled(_ ruuviTagId: String, after date: Date, with intervalMinutes: Int, pick points: Double) async throws -> [RuuviTagSensorRecord] {
        readDownsampledCalls.append((ruuviTagId, date, intervalMinutes, points))
        return downsampledResult
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        readSensorSettingsSensors.append(ruuviTag.any)
        return sensorSettingsResult
    }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: value,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }

    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }

    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            description: description,
            descriptionLastUpdated: descriptionLastUpdated
        )
    }

    func deleteOffsetCorrection(ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func save(sensorSettings: SensorSettings) async throws -> SensorSettings { sensorSettings }
    func cleanupDBSpace() async throws -> Bool { true }
    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] { queuedRequestsResult }
    func readQueuedRequests(for key: String) async throws -> [RuuviCloudQueuedRequest] {
        readQueuedRequestsKeys.append(key)
        return queuedRequestsForKeyResult
    }

    func readQueuedRequests(for type: RuuviCloudQueuedRequestType) async throws -> [RuuviCloudQueuedRequest] {
        readQueuedRequestsTypes.append(type)
        return queuedRequestsForTypeResult
    }

    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool { true }
    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool { true }
    func deleteQueuedRequests() async throws -> Bool { true }
    func save(subscription: CloudSensorSubscription) async throws -> CloudSensorSubscription { subscription }
    func readSensorSubscriptionSettings(_ ruuviTag: RuuviTagSensor) async throws -> CloudSensorSubscription? { nil }
}

private func makeRecord(date: Date = Date(timeIntervalSince1970: 1)) -> RuuviTagSensorRecord {
    RuuviTagSensorRecordStruct(
        luid: "luid-1".luid,
        date: date,
        source: .advertisement,
        macId: "AA:BB:CC:11:22:33".mac,
        rssi: -70,
        version: 5,
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
        voc: nil,
        nox: nil,
        luminance: nil,
        dbaInstant: nil,
        dbaAvg: nil,
        dbaPeak: nil,
        temperatureOffset: 0,
        humidityOffset: 0,
        pressureOffset: 0
    )
}

private func makeRequest(
    type: RuuviCloudQueuedRequestType = .sensor,
    uniqueKey: String = "request-1"
) -> RuuviCloudQueuedRequest {
    RuuviCloudQueuedRequestStruct(
        id: 1,
        type: type,
        status: nil,
        uniqueKey: uniqueKey,
        requestDate: Date(timeIntervalSince1970: 1),
        successDate: nil,
        attempts: 0,
        requestBodyData: nil,
        additionalData: nil
    )
}

private func makeSensor(
    macId: String? = "AA:BB:CC:11:22:33",
    isClaimed: Bool = true,
    isOwner: Bool = true,
    isCloud: Bool = true
) -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: "luid-1".luid,
        macId: macId?.mac,
        serviceUUID: nil,
        isConnectable: true,
        name: "Sensor",
        isClaimed: isClaimed,
        isOwner: isOwner,
        owner: "owner@example.com",
        ownersPlan: nil,
        isCloudSensor: isCloud,
        canShare: true,
        sharedTo: [],
        maxHistoryDays: nil
    )
}

private struct DummyError: Error {}
