@testable import RuuviContext
@testable import RuuviPersistence
import GRDB
import RuuviOntology
import XCTest

final class RuuviPersistenceStatefulTests: XCTestCase {
    func testCreateReadUpdateAndDeleteSensorRoundTrip() async throws {
        let sut = try makePersistence()
        let sensor = makeSensor(name: "Original")

        let created = try await sut.create(sensor)
        let allSensors = try await sut.readAll()
        let storedSensor = try await sut.readOne(sensor.id)
        XCTAssertTrue(created)
        XCTAssertTrue(allSensors.contains(where: { $0.id == sensor.id && $0.name == "Original" }))
        XCTAssertEqual(storedSensor.name, "Original")

        let updatedSensor = sensor.with(name: "Updated")
        let updated = try await sut.update(updatedSensor)
        let rereadSensor = try await sut.readOne(sensor.id)
        XCTAssertTrue(updated)
        XCTAssertEqual(rereadSensor.name, "Updated")

        let deleted = try await sut.delete(updatedSensor)
        XCTAssertTrue(deleted)

        do {
            _ = try await sut.readOne(sensor.id)
            XCTFail("Expected missing sensor error")
        } catch let error as RuuviPersistenceError {
            guard case .failedToFindRuuviTag = error else {
                return XCTFail("Unexpected persistence error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateRecordRoundTripForStoredSensor() async throws {
        let sut = try makePersistence()
        let sensor = makeSensor()
        let record = makeRecord(
            macId: try XCTUnwrap(sensor.macId).value,
            luid: try XCTUnwrap(sensor.luid).value
        )

        let createdSensor = try await sut.create(sensor)
        let createdRecord = try await sut.create(record)
        XCTAssertTrue(createdSensor)
        XCTAssertTrue(createdRecord)

        let records = try await sut.readAll(sensor.id)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.macId?.value, sensor.macId?.value)
        XCTAssertEqual(records.first?.luid?.value, sensor.luid?.value)
    }

    func testCreateLastAndUpdateLastRoundTripForLatestRecord() async throws {
        let sut = try makePersistence()
        let sensor = makeSensor()
        let initial = makeRecord(
            macId: try XCTUnwrap(sensor.macId).value,
            luid: try XCTUnwrap(sensor.luid).value,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            measurementSequenceNumber: 1
        )
        let updated = makeRecord(
            macId: try XCTUnwrap(sensor.macId).value,
            luid: try XCTUnwrap(sensor.luid).value,
            date: Date(timeIntervalSince1970: 1_700_000_100),
            measurementSequenceNumber: 2
        )

        _ = try await sut.create(sensor)
        _ = try await sut.createLast(initial)
        let initialLatest = try await sut.readLatest(sensor)
        XCTAssertEqual(initialLatest?.measurementSequenceNumber, 1)

        _ = try await sut.updateLast(updated)
        let latest = try await sut.readLatest(sensor)
        XCTAssertEqual(latest?.measurementSequenceNumber, 2)
        XCTAssertEqual(latest?.date, updated.date)
    }

    func testSaveAndDeleteSensorSettingsRoundTrip() async throws {
        let sut = try makePersistence()
        let sensor = makeSensor()
        let settings = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: 1.5,
            humidityOffset: 2.5,
            pressureOffset: 3.5,
            displayOrder: ["temperature", "humidity"],
            defaultDisplayOrder: false
        )

        _ = try await sut.create(sensor)
        let saved = try await sut.save(sensorSettings: settings)
        let loaded = try await sut.readSensorSettings(sensor)
        XCTAssertEqual(saved.temperatureOffset, settings.temperatureOffset)
        XCTAssertEqual(loaded?.displayOrder ?? [], ["temperature", "humidity"])
        XCTAssertEqual(loaded?.defaultDisplayOrder, false)

        let deleted = try await sut.deleteSensorSettings(sensor)
        let afterDelete = try await sut.readSensorSettings(sensor)
        XCTAssertTrue(deleted)
        XCTAssertNil(afterDelete)
    }

    func testReadFiltersAndCountsRecordsByDateAndInterval() async throws {
        let sut = try makePersistence()
        let sensor = makeSensor()
        let baseDate = Date(timeIntervalSince1970: 1_700_000_040)
        let records = [
            makeRecord(
                macId: try XCTUnwrap(sensor.macId).value,
                luid: try XCTUnwrap(sensor.luid).value,
                date: baseDate,
                measurementSequenceNumber: 1
            ),
            makeRecord(
                macId: try XCTUnwrap(sensor.macId).value,
                luid: try XCTUnwrap(sensor.luid).value,
                date: baseDate.addingTimeInterval(60),
                measurementSequenceNumber: 2
            ),
            makeRecord(
                macId: try XCTUnwrap(sensor.macId).value,
                luid: try XCTUnwrap(sensor.luid).value,
                date: baseDate.addingTimeInterval(180),
                measurementSequenceNumber: 3
            ),
        ]

        _ = try await sut.create(sensor)
        _ = try await sut.create(records)

        let allAfter = try await sut.readAll(sensor.id, after: baseDate.addingTimeInterval(30))
        let groupedAfter = try await sut.read(
            sensor.id,
            after: baseDate.addingTimeInterval(-1),
            with: 120
        )
        let groupedAll = try await sut.readAll(sensor.id, with: 120)
        let recent = try await sut.readLast(sensor.id, from: baseDate.addingTimeInterval(30).timeIntervalSince1970)
        let storedTagCount = try await sut.getStoredTagsCount()
        let storedMeasurementsCount = try await sut.getStoredMeasurementsCount()

        XCTAssertEqual(allAfter.map(\.measurementSequenceNumber), [2, 3])
        XCTAssertEqual(groupedAfter.map(\.measurementSequenceNumber), [1, 3])
        XCTAssertEqual(groupedAll.map(\.measurementSequenceNumber), [1, 3])
        XCTAssertEqual(recent.map(\.measurementSequenceNumber), [2, 3])
        XCTAssertEqual(storedTagCount, 1)
        XCTAssertEqual(storedMeasurementsCount, 3)
    }

    func testDownsampleReadLastAndDeleteRecordVariants() async throws {
        let sut = try makePersistence()
        let sensor = makeSensor(macId: "AA:BB:CC:DD:EE:01", luid: "record-variants")
        let baseDate = Date().addingTimeInterval(-900)
        let records = [
            makeRecord(
                macId: try XCTUnwrap(sensor.macId).value,
                luid: try XCTUnwrap(sensor.luid).value,
                date: baseDate.addingTimeInterval(60),
                measurementSequenceNumber: 1
            ),
            makeRecord(
                macId: try XCTUnwrap(sensor.macId).value,
                luid: try XCTUnwrap(sensor.luid).value,
                date: baseDate.addingTimeInterval(180),
                measurementSequenceNumber: 2
            ),
            makeRecord(
                macId: try XCTUnwrap(sensor.macId).value,
                luid: try XCTUnwrap(sensor.luid).value,
                date: baseDate.addingTimeInterval(780),
                measurementSequenceNumber: 3
            ),
        ]
        let latest = makeRecord(
            macId: try XCTUnwrap(sensor.macId).value,
            luid: try XCTUnwrap(sensor.luid).value,
            date: baseDate.addingTimeInterval(840),
            measurementSequenceNumber: 9
        )

        _ = try await sut.create(sensor)
        _ = try await sut.create(records)
        _ = try await sut.createLast(latest)

        let downsampled = try await sut.readDownsampled(
            sensor.id,
            after: baseDate,
            with: 5,
            pick: 2
        )
        let lastHistorical = try await sut.readLast(sensor)
        let latestBeforeDelete = try await sut.readLatest(sensor)
        let deletedLatest = try await sut.deleteLatest(sensor.id)
        let latestAfterDelete = try await sut.readLatest(sensor)
        let deletedBefore = try await sut.deleteAllRecords(
            sensor.id,
            before: baseDate.addingTimeInterval(200)
        )
        let recordsAfterPartialDelete = try await sut.readAll(sensor.id)
        let deletedAll = try await sut.deleteAllRecords(sensor.id)
        let recordsAfterDeleteAll = try await sut.readAll(sensor.id)

        XCTAssertFalse(downsampled.isEmpty)
        XCTAssertTrue(downsampled.contains { $0.measurementSequenceNumber == 3 })
        XCTAssertEqual(lastHistorical?.measurementSequenceNumber, 3)
        XCTAssertEqual(latestBeforeDelete?.measurementSequenceNumber, 9)
        XCTAssertTrue(deletedLatest)
        XCTAssertNil(latestAfterDelete)
        XCTAssertTrue(deletedBefore)
        XCTAssertEqual(recordsAfterPartialDelete.map(\.measurementSequenceNumber), [3])
        XCTAssertTrue(deletedAll)
        XCTAssertTrue(recordsAfterDeleteAll.isEmpty)
    }

    func testQueuedRequestsDeduplicateByTypeAndKeyAndSupportFilters() async throws {
        let sut = try makePersistence()
        let initial = try makeQueuedRequest(
            type: .sensor,
            key: "sensor-name",
            attempts: nil,
            requestDate: Date(timeIntervalSince1970: 10),
            body: ["name": "Kitchen"]
        )
        let retried = try makeQueuedRequest(
            type: .sensor,
            key: "sensor-name",
            attempts: 0,
            requestDate: Date(timeIntervalSince1970: 20),
            body: ["name": "Updated Kitchen"]
        )
        let second = try makeQueuedRequest(
            type: .settings,
            key: "settings-1",
            attempts: 0,
            requestDate: Date(timeIntervalSince1970: 30),
            body: ["setting": "cloud"]
        )

        let createdInitial = try await sut.createQueuedRequest(initial)
        let createdRetried = try await sut.createQueuedRequest(retried)
        let createdSecond = try await sut.createQueuedRequest(second)

        let allRequests = try await sut.readQueuedRequests()
        let keyedRequests = try await sut.readQueuedRequests(for: "sensor-name")
        let typedRequests = try await sut.readQueuedRequests(for: .sensor)

        XCTAssertTrue(createdInitial)
        XCTAssertTrue(createdRetried)
        XCTAssertTrue(createdSecond)
        XCTAssertEqual(allRequests.count, 2)
        XCTAssertEqual(keyedRequests.count, 1)
        XCTAssertEqual(typedRequests.count, 1)
        XCTAssertEqual(keyedRequests.first?.attempts, 1)
        XCTAssertEqual(keyedRequests.first?.requestDate, retried.requestDate)
        XCTAssertEqual(keyedRequests.first?.requestBodyData, retried.requestBodyData)

        let deletedQueued = try await sut.deleteQueuedRequest(try XCTUnwrap(keyedRequests.first))
        let remainingAfterDelete = try await sut.readQueuedRequests()
        let deletedAllQueued = try await sut.deleteQueuedRequests()
        let remainingAfterDeleteAll = try await sut.readQueuedRequests()
        XCTAssertTrue(deletedQueued)
        XCTAssertEqual(remainingAfterDelete.count, 1)
        XCTAssertTrue(deletedAllQueued)
        XCTAssertTrue(remainingAfterDeleteAll.isEmpty)
    }

    func testOffsetDisplayDescriptionAndSubscriptionRoundTrip() async throws {
        let sut = try makePersistence()
        let sensor = makeSensor()
        let record = makeRecord(
            macId: try XCTUnwrap(sensor.macId).value,
            luid: try XCTUnwrap(sensor.luid).value
        )
        let displayUpdatedAt = Date(timeIntervalSince1970: 100)
        let defaultUpdatedAt = Date(timeIntervalSince1970: 110)
        let descriptionUpdatedAt = Date(timeIntervalSince1970: 120)

        _ = try await sut.create(sensor)
        let offsetSettings = try await sut.updateOffsetCorrection(
            type: .humidity,
            with: 0.25,
            of: sensor,
            lastOriginalRecord: record
        )
        let recordsAfterOffset = try await sut.readAll(sensor.id)
        let deletedOffset = try await sut.deleteOffsetCorrection(ruuviTag: sensor)
        let settingsAfterDelete = try await sut.readSensorSettings(sensor)
        XCTAssertEqual(offsetSettings.humidityOffset, 0.25)
        XCTAssertEqual(recordsAfterOffset.count, 1)
        XCTAssertTrue(deletedOffset)
        XCTAssertNil(settingsAfterDelete)

        let displaySettings = try await sut.updateDisplaySettings(
            for: sensor,
            displayOrder: ["humidity", "temperature"],
            defaultDisplayOrder: false,
            displayOrderLastUpdated: displayUpdatedAt,
            defaultDisplayOrderLastUpdated: defaultUpdatedAt
        )
        let described = try await sut.updateDescription(
            for: sensor,
            description: "Basement",
            descriptionLastUpdated: descriptionUpdatedAt
        )
        let subscription = SubscriptionStub(
            macId: sensor.macId?.value,
            subscriptionName: "pro",
            isActive: true,
            maxClaims: 10,
            maxHistoryDays: 365,
            maxResolutionMinutes: 5,
            maxShares: 8,
            maxSharesPerSensor: 3,
            delayedAlertAllowed: true,
            emailAlertAllowed: true,
            offlineAlertAllowed: true,
            pdfExportAllowed: true,
            pushAlertAllowed: true,
            telegramAlertAllowed: false,
            endAt: "2099-01-01"
        )
        _ = try await sut.save(subscription: subscription)
        let loadedSettings = try await sut.readSensorSettings(sensor)
        let loadedSubscription = try await sut.readSensorSubscriptionSettings(sensor)

        XCTAssertEqual(displaySettings.displayOrder ?? [], ["humidity", "temperature"])
        XCTAssertEqual(displaySettings.defaultDisplayOrder, false)
        XCTAssertEqual(displaySettings.displayOrderLastUpdated, displayUpdatedAt)
        XCTAssertEqual(displaySettings.defaultDisplayOrderLastUpdated, defaultUpdatedAt)
        XCTAssertEqual(described.description, "Basement")
        XCTAssertEqual(described.descriptionLastUpdated, descriptionUpdatedAt)
        XCTAssertEqual(loadedSettings?.displayOrder ?? [], ["humidity", "temperature"])
        XCTAssertEqual(loadedSettings?.description, "Basement")
        let cleanedUp = try await sut.cleanupDBSpace()
        XCTAssertEqual(loadedSubscription?.subscriptionName, "pro")
        XCTAssertEqual(loadedSubscription?.maxHistoryDays, 365)
        XCTAssertTrue(cleanedUp)
    }

    func testOffsetCorrectionUpdatesExistingSettingsAndHandlesMissingDeletion() async throws {
        let sut = try makePersistence()
        let sensor = makeSensor(macId: "AA:BB:CC:DD:EE:02", luid: "offset-existing")
        let missingSensor = makeSensor(macId: "AA:BB:CC:DD:EE:03", luid: "offset-missing")

        _ = try await sut.create(sensor)
        let temperatureSettings = try await sut.updateOffsetCorrection(
            type: .temperature,
            with: 1.25,
            of: sensor,
            lastOriginalRecord: nil
        )
        let pressureSettings = try await sut.updateOffsetCorrection(
            type: .pressure,
            with: 100.5,
            of: sensor,
            lastOriginalRecord: nil
        )
        let loadedSettings = try await sut.readSensorSettings(sensor)
        let deletedMissing = try await sut.deleteOffsetCorrection(ruuviTag: missingSensor)

        XCTAssertEqual(temperatureSettings.temperatureOffset, 1.25)
        XCTAssertEqual(pressureSettings.temperatureOffset, 1.25)
        XCTAssertEqual(pressureSettings.pressureOffset, 100.5)
        XCTAssertEqual(loadedSettings?.temperatureOffset, 1.25)
        XCTAssertEqual(loadedSettings?.pressureOffset, 100.5)
        XCTAssertFalse(deletedMissing)
    }

    func testMacNormalizationUsesStoredFullMacForLuidLikeAndCompactSuffixMatches() async throws {
        let sut = try makePersistence()
        let fullMac = "AA:BB:CC:DD:EE:FF"
        let likeMatchMac = "00:00:00:DD:EE:FF"
        let compactMatchMac = "DDEEFF"
        let sensor = makeSensor(macId: fullMac, luid: "known-luid", name: "Original")
        let sameLuidWithShortMac = makeSensor(
            macId: likeMatchMac,
            luid: "known-luid",
            name: "Normalized"
        )
        let baseDate = Date(timeIntervalSince1970: 1_700_001_000)
        let recordMatchedByLuid = makeRecord(
            macId: likeMatchMac,
            luid: "known-luid",
            date: baseDate,
            measurementSequenceNumber: 11
        )
        let recordMatchedByLikeSuffix = makeRecord(
            macId: likeMatchMac,
            luid: "suffix-luid",
            date: baseDate.addingTimeInterval(60),
            measurementSequenceNumber: 12
        )
        let recordMatchedByCompactSuffix = makeRecord(
            macId: compactMatchMac,
            luid: "compact-luid",
            date: baseDate.addingTimeInterval(120),
            measurementSequenceNumber: 13
        )

        _ = try await sut.create(sensor)
        _ = try await sut.update(sameLuidWithShortMac)
        _ = try await sut.create(recordMatchedByLuid)
        _ = try await sut.create(recordMatchedByLikeSuffix)
        _ = try await sut.create(recordMatchedByCompactSuffix)

        let normalizedSensor = try await sut.readOne(fullMac)
        let records = try await sut.readAll(fullMac)

        XCTAssertEqual(normalizedSensor.macId?.value, fullMac)
        XCTAssertEqual(normalizedSensor.name, "Normalized")
        XCTAssertEqual(records.map(\.measurementSequenceNumber), [11, 12, 13])
        XCTAssertEqual(records.map { $0.macId?.value }, [fullMac, fullMac, fullMac])
    }

    func testMissingUpdateMapsRecordNotFoundToFailedToFindRuuviTag() async throws {
        let sut = try makePersistence()
        let missingSensor = makeSensor()

        do {
            _ = try await sut.update(missingSensor)
            XCTFail("Expected missing update to throw")
        } catch let error as RuuviPersistenceError {
            guard case .failedToFindRuuviTag = error else {
                return XCTFail("Unexpected persistence error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDatabaseReadFailuresMapToGRDBErrors() async throws {
        let (sut, context) = try makePersistenceWithContext()
        try await context.database.dbPool.write { db in
            try db.drop(table: RuuviTagSQLite.databaseTableName)
        }

        do {
            _ = try await sut.readAll()
            XCTFail("Expected broken table read to throw")
        } catch let error as RuuviPersistenceError {
            guard case .grdb = error else {
                return XCTFail("Unexpected persistence error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCleanupDBSpaceMapsVacuumFailures() async throws {
        let (sut, context) = try makePersistenceWithContext()
        try context.database.dbPool.close()

        do {
            _ = try await sut.cleanupDBSpace()
            XCTFail("Expected closed database vacuum to throw")
        } catch let error as RuuviPersistenceError {
            guard case .grdb = error else {
                return XCTFail("Unexpected persistence error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSensorNormalizationKeepsUnrelatedMacsAndSupportsMissingIdentifiers() async throws {
        let sut = try makePersistence()
        let existingMac = "AA:BB:CC:DD:EE:10"
        let unrelatedMac = "11:22:33:44:55:66"
        let existingSensor = makeSensor(macId: existingMac, luid: "shared-normalization")
        let unrelatedSensor = makeSensor(
            macId: unrelatedMac,
            luid: "shared-normalization",
            name: "Unrelated"
        )
        let exactMacLookup = makeSensor(macId: existingMac, luid: nil, name: "Exact")
        let noMacSensor = makeSensor(macId: nil, luid: "settings-without-mac")
        let noIdentifierSensor = makeSensor(macId: nil, luid: nil, name: "No Identifier")

        _ = try await sut.create(existingSensor)
        _ = try await sut.create(unrelatedSensor)
        let storedUnrelated = try await sut.readOne(unrelatedMac)
        let exactSettings = try await sut.updateDisplaySettings(
            for: exactMacLookup,
            displayOrder: ["temperature"],
            defaultDisplayOrder: true,
            displayOrderLastUpdated: nil,
            defaultDisplayOrderLastUpdated: nil
        )
        let exactSettingsByMacOnly = try await sut.readSensorSettings(exactMacLookup)
        let missingSettings = try await sut.readSensorSettings(noMacSensor)
        let missingLastRecord = try await sut.readLast(noIdentifierSensor)
        let missingLatestRecord = try await sut.readLatest(noIdentifierSensor)

        XCTAssertEqual(storedUnrelated.macId?.value, unrelatedMac)
        XCTAssertEqual(storedUnrelated.name, "Unrelated")
        XCTAssertEqual(exactSettings.macId?.value, existingMac)
        XCTAssertEqual(exactSettingsByMacOnly?.macId?.value, existingMac)
        XCTAssertNil(missingSettings)
        XCTAssertNil(missingLastRecord)
        XCTAssertNil(missingLatestRecord)
    }

    func testRecordNormalizationKeepsUnrelatedAndMissingMacs() async throws {
        let sut = try makePersistence()
        let sensor = makeSensor(macId: "AA:BB:CC:DD:EE:20", luid: "record-normalization")
        let noMacRecord = makeRecord(
            macId: nil,
            luid: "record-normalization",
            date: Date(timeIntervalSince1970: 1_700_002_000),
            measurementSequenceNumber: 21
        )
        let unrelatedRecord = makeRecord(
            macId: "11:22:33:44:55:77",
            luid: "record-normalization",
            date: Date(timeIntervalSince1970: 1_700_002_060),
            measurementSequenceNumber: 22
        )

        _ = try await sut.create(sensor)
        _ = try await sut.updateOffsetCorrection(
            type: .temperature,
            with: 1,
            of: sensor,
            lastOriginalRecord: noMacRecord
        )
        _ = try await sut.updateOffsetCorrection(
            type: .humidity,
            with: 2,
            of: sensor,
            lastOriginalRecord: unrelatedRecord
        )

        let records = try await sut.readAll("record-normalization")
        let noMacStored = records.first { $0.measurementSequenceNumber == 21 }
        let unrelatedStored = records.first { $0.measurementSequenceNumber == 22 }

        XCTAssertNil(noMacStored?.macId)
        XCTAssertEqual(unrelatedStored?.macId?.value, "11:22:33:44:55:77")
    }
}

private func makePersistence() throws -> RuuviPersistenceSQLite {
    try makePersistenceWithContext().sut
}

private func makePersistenceWithContext() throws -> (sut: RuuviPersistenceSQLite, context: SQLiteContext) {
    let database = try SQLiteGRDBDatabase(path: temporaryDatabasePath())
    let context = SQLiteContextGRDB(database: database)
    context.database.migrateIfNeeded()
    return (RuuviPersistenceSQLite(context: context), context)
}

private func temporaryDatabasePath() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("RuuviPersistenceTests-\(UUID().uuidString).sqlite")
        .path
}

private func makeSensor(
    macId: String? = uniqueMacString(),
    luid: String? = UUID().uuidString,
    name: String = "Sensor"
) -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: luid?.luid,
        macId: macId?.mac,
        serviceUUID: nil,
        isConnectable: true,
        name: name,
        isClaimed: true,
        isOwner: true,
        owner: "owner@example.com",
        ownersPlan: nil,
        isCloudSensor: false,
        canShare: false,
        sharedTo: [],
        maxHistoryDays: nil
    )
}

private func makeRecord(
    macId: String?,
    luid: String?,
    date: Date = Date(timeIntervalSince1970: 1_700_000_000),
    measurementSequenceNumber: Int? = 1
) -> RuuviTagSensorRecord {
    RuuviTagSensorRecordStruct(
        luid: luid?.luid,
        date: date,
        source: .advertisement,
        macId: macId?.mac,
        rssi: -65,
        version: 5,
        temperature: nil,
        humidity: nil,
        pressure: nil,
        acceleration: nil,
        voltage: nil,
        movementCounter: nil,
        measurementSequenceNumber: measurementSequenceNumber,
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

private func uniqueMacString() -> String {
    let hex = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    let parts = stride(from: 0, to: 12, by: 2).map { index in
        let start = hex.index(hex.startIndex, offsetBy: index)
        let end = hex.index(start, offsetBy: 2)
        return String(hex[start..<end])
    }
    return parts.joined(separator: ":")
}

private func makeQueuedRequest(
    type: RuuviCloudQueuedRequestType,
    key: String,
    attempts: Int?,
    requestDate: Date,
    body: [String: String]
) throws -> RuuviCloudQueuedRequest {
    RuuviCloudQueuedRequestStruct(
        id: nil,
        type: type,
        status: nil,
        uniqueKey: key,
        requestDate: requestDate,
        successDate: nil,
        attempts: attempts,
        requestBodyData: try JSONEncoder().encode(body),
        additionalData: nil
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
