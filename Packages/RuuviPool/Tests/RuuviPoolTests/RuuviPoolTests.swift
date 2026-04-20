@testable import RuuviPool
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import XCTest

final class RuuviPoolTests: XCTestCase {
    func testCreatePersistsSensorAndBiDirectionalIds() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let ids = IDsSpy()
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: ids,
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )
        let sensor = makeSensor()

        let success = try await sut.create(sensor)

        XCTAssertTrue(success)
        XCTAssertEqual(sqlite.createdSensors.map(\.id), [sensor.id])
        XCTAssertEqual(ids.setMacCalls.count, 2)
        XCTAssertEqual(ids.setMacCalls.last?.0.value, sensor.macId?.value)
        XCTAssertEqual(ids.setLuidCalls.last?.0.value, sensor.luid?.value)
    }

    func testUpdateRefreshesBiDirectionalIds() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let ids = IDsSpy()
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: ids,
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )
        let sensor = makeSensor()

        let success = try await sut.update(sensor)

        XCTAssertTrue(success)
        XCTAssertEqual(sqlite.updatedSensors.map(\.id), [sensor.id])
        XCTAssertEqual(ids.setMacCalls.last?.1.value, sensor.luid?.value)
        XCTAssertEqual(ids.setLuidCalls.last?.1.value, sensor.macId?.value)
    }

    func testDeleteRemovesOffsetCorrectionDeletesSensorAndStopsKeepConnection() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let connections = ConnectionsSpy()
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: connections
        )
        let sensor = makeSensor()

        let success = try await sut.delete(sensor)

        XCTAssertTrue(success)
        XCTAssertEqual(sqlite.deleteOffsetSensors.map(\.id), [sensor.id])
        XCTAssertEqual(sqlite.deletedSensors.map(\.id), [sensor.id])
        XCTAssertEqual(connections.setKeepConnectionCalls.count, 1)
        XCTAssertEqual(connections.setKeepConnectionCalls.first?.0, false)
        XCTAssertEqual(connections.setKeepConnectionCalls.first?.1, sensor.luid?.value)
    }

    func testCreateUpdateAndDeleteReturnFalseWhenSensorHasNoMacId() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )
        let sensorWithoutMac = makeSensor(macId: nil)

        let created = try await sut.create(sensorWithoutMac)
        let updated = try await sut.update(sensorWithoutMac)
        let deleted = try await sut.delete(sensorWithoutMac)

        XCTAssertFalse(created)
        XCTAssertFalse(updated)
        XCTAssertFalse(deleted)
        XCTAssertTrue(sqlite.createdSensors.isEmpty)
        XCTAssertTrue(sqlite.updatedSensors.isEmpty)
        XCTAssertTrue(sqlite.deleteOffsetSensors.isEmpty)
        XCTAssertTrue(sqlite.deletedSensors.isEmpty)
    }

    func testCreateRecordWithoutMacUsesMappedMac() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let ids = IDsSpy()
        let luid = "luid-1".luid
        let mappedMac = "AA:BB:CC:11:22:33".mac
        ids.macByLuid[luid.value] = mappedMac
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: ids,
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )
        let record = makeRecord(macId: nil, luid: luid.value)

        let success = try await sut.create(record)

        XCTAssertTrue(success)
        XCTAssertEqual(sqlite.createdRecords.first?.macId?.value, mappedMac.value)
    }

    func testCreateRecordCreateLastAndUpdateLastUseRecordMacWhenPresent() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )
        let record = makeRecord(macId: "AA:BB:CC:11:22:33")

        let created = try await sut.create(record)
        let createdLast = try await sut.createLast(record)
        let updatedLast = try await sut.updateLast(record)

        XCTAssertTrue(created)
        XCTAssertTrue(createdLast)
        XCTAssertTrue(updatedLast)
        XCTAssertEqual(sqlite.createdRecords.first?.macId?.value, record.macId?.value)
        XCTAssertEqual(sqlite.createdLastRecords.first?.macId?.value, record.macId?.value)
        XCTAssertEqual(sqlite.updatedLastRecords.first?.macId?.value, record.macId?.value)
    }

    func testCreateRecordCreateLastAndUpdateLastReturnFalseWhenMacCannotBeResolved() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )
        let record = makeRecord(macId: nil, luid: "missing-luid")

        let created = try await sut.create(record)
        let createdLast = try await sut.createLast(record)
        let updatedLast = try await sut.updateLast(record)

        XCTAssertFalse(created)
        XCTAssertFalse(createdLast)
        XCTAssertFalse(updatedLast)
        XCTAssertTrue(sqlite.createdRecords.isEmpty)
        XCTAssertTrue(sqlite.createdLastRecords.isEmpty)
        XCTAssertTrue(sqlite.updatedLastRecords.isEmpty)
    }

    func testCreateRecordsFiltersOutEntriesWithoutMacId() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )
        let withMac = makeRecord(macId: "AA:BB:CC:11:22:33")
        let withoutMac = makeRecord(macId: nil)

        let success = try await sut.create([withMac, withoutMac])

        XCTAssertTrue(success)
        XCTAssertEqual(sqlite.createdRecordBatches.count, 1)
        XCTAssertEqual(sqlite.createdRecordBatches.first?.count, 1)
        XCTAssertEqual(sqlite.createdRecordBatches.first?.first?.macId?.value, withMac.macId?.value)
    }

    func testQueuedRequestsAndSubscriptionPassThroughPersistence() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )
        let request = makeRequest()
        let subscription = makeSubscription()

        let created = try await sut.createQueuedRequest(request)
        let deleted = try await sut.deleteQueuedRequest(request)
        let deletedAll = try await sut.deleteQueuedRequests()
        let savedSubscription = try await sut.save(subscription: subscription)
        let loadedSubscription = try await sut.readSensorSubscriptionSettings(makeSensor())

        XCTAssertTrue(created)
        XCTAssertTrue(deleted)
        XCTAssertTrue(deletedAll)
        XCTAssertEqual(sqlite.createdQueuedRequests.map(\.uniqueKey), [request.uniqueKey])
        XCTAssertEqual(sqlite.deletedQueuedRequests.map(\.uniqueKey), [request.uniqueKey])
        XCTAssertEqual(sqlite.deleteAllQueuedRequestsCount, 1)
        XCTAssertEqual(savedSubscription.id, subscription.id)
        XCTAssertEqual(loadedSubscription?.id, subscription.id)
    }

    func testCreateLastAndUpdateLastUseMappedMacWhenOnlyLuidIsAvailable() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let ids = IDsSpy()
        let luid = "luid-last".luid
        let mappedMac = "AA:BB:CC:11:22:33".mac
        ids.macByLuid[luid.value] = mappedMac
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: ids,
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )
        let record = makeRecord(macId: nil, luid: luid.value)

        let created = try await sut.createLast(record)
        let updated = try await sut.updateLast(record)

        XCTAssertTrue(created)
        XCTAssertTrue(updated)
        XCTAssertEqual(sqlite.createdLastRecords.first?.macId?.value, mappedMac.value)
        XCTAssertEqual(sqlite.updatedLastRecords.first?.macId?.value, mappedMac.value)
    }

    func testDeleteLastDeleteSensorSettingsCleanupAndReadSettingsDelegateToPersistence() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let sensor = makeSensor()
        let expectedSettings = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: 1,
            humidityOffset: 2,
            pressureOffset: 3
        )
        sqlite.sensorSettingsToRead = expectedSettings
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )

        let deletedLast = try await sut.deleteLast(sensor.id)
        let deletedSettings = try await sut.deleteSensorSettings(sensor)
        let cleaned = try await sut.cleanupDBSpace()
        let loadedSettings = try await sut.readSensorSettings(sensor)

        XCTAssertTrue(deletedLast)
        XCTAssertTrue(deletedSettings)
        XCTAssertTrue(cleaned)
        XCTAssertEqual(sqlite.deletedLatestIDs, [sensor.id])
        XCTAssertEqual(sqlite.deletedSensorSettingsIDs, [sensor.id])
        XCTAssertEqual(sqlite.cleanupDBSpaceCalls, 1)
        XCTAssertEqual(sqlite.readSensorSettingsIDs, [sensor.id])
        XCTAssertEqual(loadedSettings?.temperatureOffset, expectedSettings.temperatureOffset)
    }

    func testDeleteAllRecordsOverloadsDelegateToPersistence() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let sensor = makeSensor()
        let cutoff = Date(timeIntervalSince1970: 1_700_000_123)
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )

        let deletedAll = try await sut.deleteAllRecords(sensor.id)
        let deletedBefore = try await sut.deleteAllRecords(sensor.id, before: cutoff)

        XCTAssertTrue(deletedAll)
        XCTAssertTrue(deletedBefore)
        XCTAssertEqual(sqlite.deletedAllRecordIDs, [sensor.id])
        XCTAssertEqual(sqlite.deletedAllRecordsBeforeRequests.count, 1)
        XCTAssertEqual(sqlite.deletedAllRecordsBeforeRequests.first?.id, sensor.id)
        XCTAssertEqual(sqlite.deletedAllRecordsBeforeRequests.first?.date, cutoff)
    }

    func testUpdateOffsetCorrectionDelegatesAndFailsForSensorsWithoutMac() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let sensor = makeSensor()
        let originalRecord = makeRecord(
            macId: sensor.macId?.value,
            luid: sensor.luid?.value ?? "luid"
        )
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )

        let settings = try await sut.updateOffsetCorrection(
            type: .temperature,
            with: 1.5,
            of: sensor,
            lastOriginalRecord: originalRecord
        )

        XCTAssertEqual(settings.temperatureOffset, 1.5)
        XCTAssertEqual(sqlite.updatedOffsetCorrectionRequests.count, 1)
        XCTAssertEqual(
            sqlite.updatedOffsetCorrectionRequests.first?.record?.macId?.value,
            sensor.macId?.value
        )

        let sensorWithoutMac = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: "1.0.0",
            luid: "macless-luid".luid,
            macId: nil,
            serviceUUID: nil,
            isConnectable: true,
            name: "macless",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: nil,
            isCloudSensor: false,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: nil
        )

        do {
            _ = try await sut.updateOffsetCorrection(
                type: .temperature,
                with: 1.5,
                of: sensorWithoutMac,
                lastOriginalRecord: nil
            )
            XCTFail("Expected missing sensor error")
        } catch let error as RuuviPoolError {
            guard case let .ruuviPersistence(persistenceError) = error,
                  case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Unexpected pool error: \(error)")
            }
        }
    }

    func testUpdateDisplaySettingsAndDescriptionPassThroughPersistence() async throws {
        let sqlite = PersistenceCoordinatorSpy()
        let sensor = makeSensor()
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )

        let displaySettings = try await sut.updateDisplaySettings(
            for: sensor,
            displayOrder: ["temperature", "humidity"],
            defaultDisplayOrder: false,
            displayOrderLastUpdated: updatedAt,
            defaultDisplayOrderLastUpdated: updatedAt
        )
        let descriptionSettings = try await sut.updateDescription(
            for: sensor,
            description: "Basement",
            descriptionLastUpdated: updatedAt
        )

        XCTAssertEqual(displaySettings.displayOrder ?? [], ["temperature", "humidity"])
        XCTAssertEqual(displaySettings.defaultDisplayOrder, false)
        XCTAssertEqual(sqlite.updatedDisplaySettingsIDs, [sensor.id])
        XCTAssertEqual(descriptionSettings.description, "Basement")
        XCTAssertEqual(descriptionSettings.descriptionLastUpdated, updatedAt)
        XCTAssertEqual(sqlite.updatedDescriptionIDs, [sensor.id])
    }

    func testPoolOperationWrapsUnexpectedPersistenceErrors() async {
        let sqlite = PersistenceCoordinatorSpy()
        sqlite.createSensorError = DummyError()
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )

        do {
            _ = try await sut.create(makeSensor())
            XCTFail("Expected wrapped pool error")
        } catch let error as RuuviPoolError {
            guard case let .ruuviPersistence(persistenceError) = error,
                  case .grdb = persistenceError else {
                return XCTFail("Unexpected pool error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPoolOperationPreservesPoolErrorsAndWrapsPersistenceErrors() async {
        let sqlite = PersistenceCoordinatorSpy()
        let sut = RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )

        sqlite.deleteAllRecordsError = RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        do {
            _ = try await sut.deleteAllRecords("sensor-1")
            XCTFail("Expected pool error")
        } catch let error as RuuviPoolError {
            guard case let .ruuviPersistence(persistenceError) = error,
                  case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Unexpected pool error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        sqlite.deleteAllRecordsError = RuuviPersistenceError.failedToFindRuuviTag
        do {
            _ = try await sut.deleteAllRecords("sensor-2")
            XCTFail("Expected wrapped persistence error")
        } catch let error as RuuviPoolError {
            guard case let .ruuviPersistence(persistenceError) = error,
                  case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Unexpected pool error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConvenienceOffsetCorrectionOverloadPassesNilLastOriginalRecord() async throws {
        let sut = PoolSpy()
        let sensor = makeSensor()

        _ = try await sut.updateOffsetCorrection(
            type: .temperature,
            with: 1.5,
            of: sensor
        )

        XCTAssertNil(sut.capturedLastOriginalRecord)
    }

    func testPoolErrorPreservesPersistenceError() {
        let error = RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)

        guard case let .ruuviPersistence(persistenceError) = error else {
            return XCTFail("Expected wrapped persistence error")
        }
        guard case .failedToFindRuuviTag = persistenceError else {
            return XCTFail("Expected failedToFindRuuviTag")
        }
    }

    func testFactoryCreatesCoordinator() {
        let factory = RuuviPoolFactoryCoordinator()

        let pool = factory.create(
            sqlite: PersistenceCoordinatorSpy(),
            idPersistence: IDsSpy(),
            settings: SettingsStub(),
            connectionPersistence: ConnectionsSpy()
        )

        XCTAssertTrue(pool is RuuviPoolCoordinator)
    }
}

private final class PoolSpy: RuuviPool {
    var capturedLastOriginalRecord: RuuviTagSensorRecord?

    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func create(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func deleteLast(_ ruuviTagId: String) async throws -> Bool { true }
    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool { true }
    func cleanupDBSpace() async throws -> Bool { true }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        capturedLastOriginalRecord = record
        return SensorSettingsStruct(
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
            pressureOffset: nil,
            displayOrder: displayOrder,
            defaultDisplayOrder: defaultDisplayOrder,
            displayOrderLastUpdated: displayOrderLastUpdated,
            defaultDisplayOrderLastUpdated: defaultDisplayOrderLastUpdated
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

private final class PersistenceCoordinatorSpy: RuuviPersistence {
    var createdSensors: [AnyRuuviTagSensor] = []
    var updatedSensors: [AnyRuuviTagSensor] = []
    var deletedSensors: [AnyRuuviTagSensor] = []
    var deleteOffsetSensors: [AnyRuuviTagSensor] = []
    var createdRecords: [AnyRuuviTagSensorRecord] = []
    var createdLastRecords: [AnyRuuviTagSensorRecord] = []
    var updatedLastRecords: [AnyRuuviTagSensorRecord] = []
    var createdRecordBatches: [[RuuviTagSensorRecord]] = []
    var createdQueuedRequests: [RuuviCloudQueuedRequest] = []
    var deletedQueuedRequests: [RuuviCloudQueuedRequest] = []
    var deleteAllQueuedRequestsCount = 0
    var deletedLatestIDs: [String] = []
    var deletedAllRecordIDs: [String] = []
    var deletedAllRecordsBeforeRequests: [(id: String, date: Date)] = []
    var deletedSensorSettingsIDs: [String] = []
    var readSensorSettingsIDs: [String] = []
    var updatedDisplaySettingsIDs: [String] = []
    var updatedDescriptionIDs: [String] = []
    var updatedOffsetCorrectionRequests: [(type: OffsetCorrectionType, value: Double?, sensor: AnyRuuviTagSensor, record: AnyRuuviTagSensorRecord?)] = []
    var cleanupDBSpaceCalls = 0
    var createSensorError: Error?
    var deleteAllRecordsError: Error?
    var deleteAllRecordsBeforeError: Error?
    var updateOffsetCorrectionError: Error?
    var subscriptionToRead: CloudSensorSubscription = makeSubscription()
    var sensorSettingsToRead: SensorSettings?

    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        if let createSensorError {
            throw createSensorError
        }
        createdSensors.append(ruuviTag.any)
        return true
    }

    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        updatedSensors.append(ruuviTag.any)
        return true
    }

    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        deletedSensors.append(ruuviTag.any)
        return true
    }

    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool {
        if let deleteAllRecordsError {
            throw deleteAllRecordsError
        }
        deletedAllRecordIDs.append(ruuviTagId)
        return true
    }

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool {
        if let deleteAllRecordsBeforeError {
            throw deleteAllRecordsBeforeError
        }
        deletedAllRecordsBeforeRequests.append((ruuviTagId, date))
        return true
    }

    func create(_ record: RuuviTagSensorRecord) async throws -> Bool {
        createdRecords.append(record.any)
        return true
    }

    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        createdLastRecords.append(record.any)
        return true
    }

    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        updatedLastRecords.append(record.any)
        return true
    }

    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool {
        createdRecordBatches.append(records)
        return true
    }

    func readAll() async throws -> [AnyRuuviTagSensor] { [] }
    func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ ruuviTagId: String, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ ruuviTagId: String, after date: Date) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTagId: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { nil }
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { nil }
    func deleteLatest(_ ruuviTagId: String) async throws -> Bool {
        deletedLatestIDs.append(ruuviTagId)
        return true
    }
    func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor { makeSensor().any }
    func getStoredTagsCount() async throws -> Int { 0 }
    func getStoredMeasurementsCount() async throws -> Int { 0 }
    func read(_ ruuviTagId: String, after date: Date, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readDownsampled(_ ruuviTagId: String, after date: Date, with intervalMinutes: Int, pick points: Double) async throws -> [RuuviTagSensorRecord] { [] }
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        readSensorSettingsIDs.append(ruuviTag.id)
        return sensorSettingsToRead
    }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        if let updateOffsetCorrectionError {
            throw updateOffsetCorrectionError
        }
        updatedOffsetCorrectionRequests.append((type, value, ruuviTag.any, record?.any))
        return SensorSettingsStruct(
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
        updatedDisplaySettingsIDs.append(ruuviTag.id)
        return SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            displayOrder: displayOrder,
            defaultDisplayOrder: defaultDisplayOrder,
            displayOrderLastUpdated: displayOrderLastUpdated,
            defaultDisplayOrderLastUpdated: defaultDisplayOrderLastUpdated
        )
    }

    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws -> SensorSettings {
        updatedDescriptionIDs.append(ruuviTag.id)
        return SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            description: description,
            descriptionLastUpdated: descriptionLastUpdated
        )
    }

    func deleteOffsetCorrection(ruuviTag: RuuviTagSensor) async throws -> Bool {
        deleteOffsetSensors.append(ruuviTag.any)
        return true
    }

    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        deletedSensorSettingsIDs.append(ruuviTag.id)
        return true
    }
    func save(sensorSettings: SensorSettings) async throws -> SensorSettings { sensorSettings }
    func cleanupDBSpace() async throws -> Bool {
        cleanupDBSpaceCalls += 1
        return true
    }
    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for key: String) async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for type: RuuviCloudQueuedRequestType) async throws -> [RuuviCloudQueuedRequest] { [] }

    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool {
        createdQueuedRequests.append(request)
        return true
    }

    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool {
        deletedQueuedRequests.append(request)
        return true
    }

    func deleteQueuedRequests() async throws -> Bool {
        deleteAllQueuedRequestsCount += 1
        return true
    }

    func save(subscription: CloudSensorSubscription) async throws -> CloudSensorSubscription {
        subscription
    }

    func readSensorSubscriptionSettings(_ ruuviTag: RuuviTagSensor) async throws -> CloudSensorSubscription? {
        subscriptionToRead
    }
}

private final class IDsSpy: RuuviLocalIDs {
    var macByLuid: [String: MACIdentifier] = [:]
    var luidByMac: [String: LocalIdentifier] = [:]
    var fullMacByMac: [String: MACIdentifier] = [:]
    var setMacCalls: [(MACIdentifier, LocalIdentifier)] = []
    var setLuidCalls: [(LocalIdentifier, MACIdentifier)] = []

    func mac(for luid: LocalIdentifier) -> MACIdentifier? { macByLuid[luid.value] }
    func set(mac: MACIdentifier, for luid: LocalIdentifier) {
        macByLuid[luid.value] = mac
        setMacCalls.append((mac, luid))
    }

    func extendedLuid(for mac: MACIdentifier) -> LocalIdentifier? { nil }
    func luid(for mac: MACIdentifier) -> LocalIdentifier? { luidByMac[mac.value] }
    func set(luid: LocalIdentifier, for mac: MACIdentifier) {
        luidByMac[mac.value] = luid
        setLuidCalls.append((luid, mac))
    }

    func set(extendedLuid: LocalIdentifier, for mac: MACIdentifier) {}
    func fullMac(for mac: MACIdentifier) -> MACIdentifier? { fullMacByMac[mac.value] }
    func originalMac(for fullMac: MACIdentifier) -> MACIdentifier? { nil }
    func set(fullMac: MACIdentifier, for mac: MACIdentifier) {
        fullMacByMac[mac.value] = fullMac
    }

    func removeFullMac(for mac: MACIdentifier) {
        fullMacByMac[mac.value] = nil
    }
}

private final class ConnectionsSpy: RuuviLocalConnections {
    var setKeepConnectionCalls: [(Bool, String)] = []

    var keepConnectionUUIDs: [AnyLocalIdentifier] { [] }
    func keepConnection(to luid: LocalIdentifier) -> Bool { false }
    func setKeepConnection(_ value: Bool, for luid: LocalIdentifier) {
        setKeepConnectionCalls.append((value, luid.value))
    }

    func unpairAllConnection() {}
}

private struct SettingsStub: RuuviLocalSettings {
    var signedInAtleastOnce = false
    var isSyncing = false
    var syncExtensiveChangesInProgress = false
    var signalVisibilityMigrationInProgress = false
    var temperatureUnit: TemperatureUnit = .celsius
    var temperatureAccuracy: MeasurementAccuracyType = .two
    var humidityUnit: HumidityUnit = .percent
    var humidityAccuracy: MeasurementAccuracyType = .two
    var pressureUnit: UnitPressure = .hectopascals
    var pressureAccuracy: MeasurementAccuracyType = .two
    var welcomeShown = false
    var showGraphLongPressTutorial = false
    var tosAccepted = false
    var analyticsConsentGiven = false
    var tagChartsLandscapeSwipeInstructionWasShown = false
    var language: Language = .english
    var cloudProfileLanguageCode: String?
    var isAdvertisementDaemonOn = false
    var advertisementDaemonIntervalMinutes = 0
    var connectionTimeout: TimeInterval = 0
    var serviceTimeout: TimeInterval = 0
    var cardsSwipeHintWasShown = false
    var alertsMuteIntervalMinutes = 0
    var movementAlertHysteresisMinutes = 0
    func movementAlertHysteresisLastEvents() -> [String: Date] { [:] }
    func setMovementAlertHysteresisLastEvents(_ values: [String: Date]) {}
    var saveHeartbeats = false
    var saveHeartbeatsIntervalMinutes = 0
    var saveHeartbeatsForegroundIntervalSeconds = 0
    var webPullIntervalMinutes = 0
    var dataPruningOffsetHours = 0
    var chartIntervalSeconds = 0
    var chartDurationHours = 0
    var chartDownsamplingOn = false
    var chartShowAllMeasurements = false
    var chartDrawDotsOn = false
    var chartStatsOn = false
    var chartShowAll = false
    var networkPullIntervalSeconds = 0
    var widgetRefreshIntervalMinutes = 0
    var forceRefreshWidget = false
    var networkPruningIntervalHours = 0
    var experimentalFeaturesEnabled = false
    var cloudModeEnabled = false
    var useSimpleWidget = false
    var appIsOnForeground = false
    var appOpenedCount = 0
    var appOpenedInitialCountToAskReview = 0
    var appOpenedCountDivisibleToAskReview = 0
    var dashboardEnabled = false
    var dashboardType: DashboardType = .image
    var dashboardTapActionType: DashboardTapActionType = .card
    var showFullSensorCardOnDashboardTap = false
    var dashboardSensorOrder: [String] = []
    var theme: RuuviTheme = .system
    var hideNFCForSensorContest = false
    var alertSound: RuuviAlertSound = .systemDefault
    var emailAlertDisabled = false
    var pushAlertDisabled = false
    var marketingPreference = false
    var limitAlertNotificationsEnabled = false
    var showSwitchStatusLabel = false
    var showAlertsRangeInGraph = false
    var useNewGraphRendering = false
    var imageCompressionQuality = 0
    var compactChartView = false
    var historySyncLegacy = false
    var historySyncOnDashboard = false
    var historySyncForEachSensor = false
    var includeDataSourceInHistoryExport = false
    var customTempAlertLowerBound = 0.0
    var customTempAlertUpperBound = 0.0
    func keepConnectionDialogWasShown(for luid: LocalIdentifier) -> Bool { false }
    func setKeepConnectionDialogWasShown(_ shown: Bool, for luid: LocalIdentifier) {}
    func firmwareUpdateDialogWasShown(for luid: LocalIdentifier) -> Bool { false }
    func setFirmwareUpdateDialogWasShown(_ shown: Bool, for luid: LocalIdentifier) {}
    func cardToOpenFromWidget() -> String? { nil }
    func setCardToOpenFromWidget(for macId: String?) {}
    func lastOpenedChart() -> String? { nil }
    func setLastOpenedChart(with id: String?) {}
    func setOwnerCheckDate(for macId: MACIdentifier?, value: Date?) {}
    func ownerCheckDate(for macId: MACIdentifier?) -> Date? { nil }
    func ledBrightnessSelection(for macId: MACIdentifier?) -> RuuviLedBrightnessLevel? { nil }
    func setLedBrightnessSelection(_ selection: RuuviLedBrightnessLevel?, for macId: MACIdentifier?) {}
    func syncDialogHidden(for luid: LocalIdentifier) -> Bool { false }
    func setSyncDialogHidden(_ hidden: Bool, for luid: LocalIdentifier) {}
    func setNotificationsBadgeCount(value: Int) {}
    func notificationsBadgeCount() -> Int { 0 }
    func showCustomTempAlertBound(for id: String) -> Bool { false }
    func setShowCustomTempAlertBound(_ show: Bool, for id: String) {}
    func dashboardSignInBannerHidden(for version: String) -> Bool { false }
    func setDashboardSignInBannerHidden(for version: String) {}
}

private func makeSensor(macId: String? = "AA:BB:CC:11:22:33") -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: "luid-1".luid,
        macId: macId?.mac,
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

private func makeRecord(macId: String?, luid: String = "luid-1") -> RuuviTagSensorRecord {
    RuuviTagSensorRecordStruct(
        luid: luid.luid,
        date: Date(timeIntervalSince1970: 1),
        source: .advertisement,
        macId: macId?.mac,
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
    uniqueKey: String = "queued-1"
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

private func makeSubscription() -> CloudSensorSubscription {
    SubscriptionStub(
        macId: "AA:BB:CC:11:22:33",
        subscriptionName: "Subscription",
        isActive: true,
        maxClaims: 1,
        maxHistoryDays: 30,
        maxResolutionMinutes: 10,
        maxShares: 3,
        maxSharesPerSensor: 1,
        delayedAlertAllowed: true,
        emailAlertAllowed: true,
        offlineAlertAllowed: true,
        pdfExportAllowed: true,
        pushAlertAllowed: true,
        telegramAlertAllowed: false,
        endAt: nil
    )
}

private struct SubscriptionStub: CloudSensorSubscription {
    var macId: String?
    var subscriptionName: String?
    var isActive: Bool?
    var maxClaims: Int?
    var maxHistoryDays: Int?
    var maxResolutionMinutes: Int?
    var maxShares: Int?
    var maxSharesPerSensor: Int?
    var delayedAlertAllowed: Bool?
    var emailAlertAllowed: Bool?
    var offlineAlertAllowed: Bool?
    var pdfExportAllowed: Bool?
    var pushAlertAllowed: Bool?
    var telegramAlertAllowed: Bool?
    var endAt: String?
}

private struct DummyError: Error {}
