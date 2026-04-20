@testable import RuuviRepository
import RuuviOntology
import RuuviPool
import RuuviStorage
import XCTest

final class RuuviRepositoryTests: XCTestCase {
    func testCreateRecordReturnsMappedRecordWhenPoolSucceeds() async throws {
        let pool = PoolSpy()
        let sut = RuuviRepositoryCoordinator(
            pool: pool,
            storage: StorageStub()
        )
        let sensor = makeSensor()
        let record = makeRecord(macId: sensor.macId!.value)

        let result = try await sut.create(record: record, for: sensor)

        XCTAssertEqual(pool.createdRecords.count, 1)
        XCTAssertEqual(result.macId?.value, sensor.macId?.value)
    }

    func testCreateRecordsReturnsMappedRecordsWhenPoolSucceeds() async throws {
        let pool = PoolSpy()
        let sut = RuuviRepositoryCoordinator(
            pool: pool,
            storage: StorageStub()
        )
        let sensor = makeSensor()
        let record = makeRecord(macId: sensor.macId!.value)

        let result = try await sut.create(records: [record], for: sensor)

        XCTAssertEqual(pool.createdRecords.count, 1)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.macId?.value, sensor.macId?.value)
    }

    func testCreateRecordWrapsPoolErrors() async {
        let pool = PoolSpy()
        pool.createRecordError = RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        let sut = RuuviRepositoryCoordinator(
            pool: pool,
            storage: StorageStub()
        )

        do {
            _ = try await sut.create(record: makeRecord(), for: makeSensor())
            XCTFail("Expected repository error")
        } catch let error as RuuviRepositoryError {
            guard case let .ruuviPool(poolError) = error else {
                return XCTFail("Expected wrapped pool error")
            }
            guard case let .ruuviPersistence(persistenceError) = poolError else {
                return XCTFail("Expected wrapped persistence error")
            }
            guard case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Expected failedToFindRuuviTag")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateRecordWrapsUnexpectedErrorsAsPoolGrdbFailures() async {
        let pool = PoolSpy()
        pool.createRecordError = DummyError()
        let sut = RuuviRepositoryCoordinator(
            pool: pool,
            storage: StorageStub()
        )

        do {
            _ = try await sut.create(record: makeRecord(), for: makeSensor())
            XCTFail("Expected repository error")
        } catch let error as RuuviRepositoryError {
            guard case let .ruuviPool(poolError) = error,
                  case let .ruuviPersistence(persistenceError) = poolError,
                  case .grdb = persistenceError else {
                return XCTFail("Unexpected repository error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateRecordPreservesRepositoryErrors() async {
        let wrappedError = RuuviRepositoryError.ruuviPool(
            .ruuviPersistence(.failedToFindRuuviTag)
        )
        let pool = PoolSpy()
        pool.createRecordError = wrappedError
        let sut = RuuviRepositoryCoordinator(
            pool: pool,
            storage: StorageStub()
        )

        do {
            _ = try await sut.create(record: makeRecord(), for: makeSensor())
            XCTFail("Expected repository error")
        } catch let error as RuuviRepositoryError {
            guard case let .ruuviPool(poolError) = error,
                  case let .ruuviPersistence(persistenceError) = poolError,
                  case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Unexpected repository error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateRecordsWrapsUnexpectedErrorsAsPoolGrdbFailures() async {
        let pool = PoolSpy()
        pool.createRecordsError = DummyError()
        let sut = RuuviRepositoryCoordinator(
            pool: pool,
            storage: StorageStub()
        )

        do {
            _ = try await sut.create(records: [makeRecord()], for: makeSensor())
            XCTFail("Expected repository error")
        } catch let error as RuuviRepositoryError {
            guard case let .ruuviPool(poolError) = error,
                  case let .ruuviPersistence(persistenceError) = poolError,
                  case .grdb = persistenceError else {
                return XCTFail("Unexpected repository error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateRecordsWrapsPoolErrors() async {
        let pool = PoolSpy()
        pool.createRecordsError = RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        let sut = RuuviRepositoryCoordinator(
            pool: pool,
            storage: StorageStub()
        )

        do {
            _ = try await sut.create(records: [makeRecord()], for: makeSensor())
            XCTFail("Expected repository error")
        } catch let error as RuuviRepositoryError {
            guard case let .ruuviPool(poolError) = error,
                  case let .ruuviPersistence(persistenceError) = poolError,
                  case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Unexpected repository error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateRecordsPreservesRepositoryErrors() async {
        let wrappedError = RuuviRepositoryError.ruuviPool(
            .ruuviPersistence(.failedToFindRuuviTag)
        )
        let pool = PoolSpy()
        pool.createRecordsError = wrappedError
        let sut = RuuviRepositoryCoordinator(
            pool: pool,
            storage: StorageStub()
        )

        do {
            _ = try await sut.create(records: [makeRecord()], for: makeSensor())
            XCTFail("Expected repository error")
        } catch let error as RuuviRepositoryError {
            guard case let .ruuviPool(poolError) = error,
                  case let .ruuviPersistence(persistenceError) = poolError,
                  case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Unexpected repository error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFactoryCreatesCoordinator() {
        let factory = RuuviRepositoryFactoryCoordinator()

        let repository = factory.create(
            pool: PoolSpy(),
            storage: StorageStub()
        )

        XCTAssertTrue(repository is RuuviRepositoryCoordinator)
    }
}

private final class PoolSpy: RuuviPool {
    var createdRecords: [RuuviTagSensorRecord] = []
    var createRecordError: Error?
    var createRecordsError: Error?

    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }

    func create(_ record: RuuviTagSensorRecord) async throws -> Bool {
        if let createRecordError {
            throw createRecordError
        }
        createdRecords = [record]
        return true
    }

    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func deleteLast(_ ruuviTagId: String) async throws -> Bool { true }

    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool {
        if let createRecordsError {
            throw createRecordsError
        }
        createdRecords = records
        return true
    }

    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool { true }
    func cleanupDBSpace() async throws -> Bool { true }

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

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? { nil }
    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool { true }
    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool { true }
    func deleteQueuedRequests() async throws -> Bool { true }

    func save(subscription: CloudSensorSubscription) async throws -> CloudSensorSubscription {
        subscription
    }

    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws -> CloudSensorSubscription? {
        nil
    }
}

private struct DummyError: Error {}

private final class StorageStub: RuuviStorage {
    func read(_ id: String, after date: Date, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readDownsampled(_ id: String, after date: Date, with intervalMinutes: Int, pick points: Double) async throws -> [RuuviTagSensorRecord] { [] }
    func readOne(_ id: String) async throws -> AnyRuuviTagSensor { makeSensor().any }
    func readAll(_ id: String) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ id: String, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ id: String, after date: Date) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll() async throws -> [AnyRuuviTagSensor] { [] }
    func readLast(_ id: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { nil }
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { nil }
    func getStoredTagsCount() async throws -> Int { 0 }
    func getClaimedTagsCount() async throws -> Int { 0 }
    func getOfflineTagsCount() async throws -> Int { 0 }
    func getStoredMeasurementsCount() async throws -> Int { 0 }
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? { nil }
    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for key: String) async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for type: RuuviCloudQueuedRequestType) async throws -> [RuuviCloudQueuedRequest] { [] }
}

private func makeSensor(macId: String = "AA:BB:CC:11:22:33") -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: "luid-1".luid,
        macId: macId.mac,
        serviceUUID: nil,
        isConnectable: true,
        name: "Sensor",
        isClaimed: true,
        isOwner: true,
        owner: "owner@example.com",
        ownersPlan: nil,
        isCloudSensor: true,
        canShare: true,
        sharedTo: [],
        maxHistoryDays: nil
    )
}

private func makeRecord(macId: String = "AA:BB:CC:11:22:33") -> RuuviTagSensorRecord {
    RuuviTagSensorRecordStruct(
        luid: "luid-1".luid,
        date: Date(),
        source: .advertisement,
        macId: macId.mac,
        rssi: -65,
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
