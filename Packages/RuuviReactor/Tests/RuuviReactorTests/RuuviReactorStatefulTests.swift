@testable import RuuviContext
@testable import RuuviReactor
import GRDB
import RuuviAnalytics
import RuuviOntology
import RuuviPersistence
import XCTest

final class RuuviReactorStatefulTests: XCTestCase {
    func testObserveEmitsInitialSensorsFromPersistence() async {
        let persistence = PersistenceSpy()
        persistence.readAllSensors = [makeSensor().any]
        let expectation = expectation(description: "initial sensors emitted")
        let sut = makeReactor(persistence: persistence)

        let token = sut.observe { change in
            guard case let .initial(sensors) = change else { return }
            XCTAssertEqual(sensors.count, 1)
            XCTAssertEqual(sensors.first?.name, "Sensor")
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1)
        token.invalidate()
    }

    func testObserveWrapsPersistenceFailures() async {
        let persistence = PersistenceSpy()
        persistence.readAllError = RuuviPersistenceError.failedToFindRuuviTag
        let expectation = expectation(description: "error emitted")
        let sut = makeReactor(persistence: persistence)

        let token = sut.observe { change in
            guard case let .error(error) = change,
                  case let .ruuviPersistence(persistenceError) = error,
                  case .failedToFindRuuviTag = persistenceError else {
                return
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1)
        token.invalidate()
    }

    func testObserveWrapsUnexpectedPersistenceFailuresAsGRDBError() async {
        let persistence = PersistenceSpy()
        persistence.readAllError = UnexpectedPersistenceError()
        let expectation = expectation(description: "unexpected error emitted")
        let sut = makeReactor(persistence: persistence)

        let token = sut.observe { change in
            guard case let .error(error) = change,
                  case let .ruuviPersistence(persistenceError) = error,
                  case let .grdb(wrappedError) = persistenceError else {
                return
            }
            XCTAssertTrue(wrappedError is UnexpectedPersistenceError)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1)
        token.invalidate()
    }

    func testObserveLastEmitsPersistedLastRecord() async {
        let persistence = PersistenceSpy()
        let sensor = makeSensor()
        persistence.lastRecord = makeRecord(macId: sensor.macId!.value, luid: sensor.luid!.value)
        let expectation = expectation(description: "last record emitted")
        let sut = makeReactor(persistence: persistence)

        let token = sut.observeLast(sensor) { change in
            guard case let .update(record) = change else { return }
            XCTAssertEqual(record?.macId?.value, sensor.macId?.value)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1)
        token.invalidate()
    }

    func testObserveLatestEmitsPersistedLatestRecord() async {
        let persistence = PersistenceSpy()
        let sensor = makeSensor()
        persistence.latestRecord = makeRecord(macId: sensor.macId!.value, luid: sensor.luid!.value)
        let expectation = expectation(description: "latest record emitted")
        let sut = makeReactor(persistence: persistence)

        let token = sut.observeLatest(sensor) { change in
            guard case let .update(record) = change else { return }
            XCTAssertEqual(record?.measurementSequenceNumber, 1)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1)
        token.invalidate()
    }

    func testObserveSensorSettingsEmitsPersistedSettings() async {
        let persistence = PersistenceSpy()
        let sensor = makeSensor()
        persistence.sensorSettings = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: 1.5,
            humidityOffset: nil,
            pressureOffset: nil
        )
        let expectation = expectation(description: "sensor settings emitted")
        let sut = makeReactor(persistence: persistence)

        let token = sut.observe(sensor) { change in
            guard case let .initial(settings) = change else { return }
            XCTAssertEqual(settings.first?.temperatureOffset, 1.5)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1)
        token.invalidate()
    }

    func testFactoryCreatesReactorImpl() {
        let reactor = RuuviReactorFactoryImpl().create(
            sqliteContext: makeSQLiteContext(),
            sqlitePersistence: PersistenceSpy(),
            errorReporter: ErrorReporterSpy()
        )

        XCTAssertTrue(reactor is RuuviReactorImpl)
    }

    func testObserveReusesExistingCombinesAndDoesNotRestartServingSubjects() throws {
        let persistence = PersistenceSpy()
        let sut = makeReactor(persistence: persistence)
        let sensor = makeUniqueSensor()
        let luid = try XCTUnwrap(sensor.luid)

        let historyToken = sut.observe(luid) { _ in }
        let secondHistoryToken = sut.observe(luid) { _ in }
        let lastToken = sut.observeLast(sensor) { _ in }
        let secondLastToken = sut.observeLast(sensor) { _ in }
        let latestToken = sut.observeLatest(sensor) { _ in }
        let secondLatestToken = sut.observeLatest(sensor) { _ in }
        let settingsToken = sut.observe(sensor) { (_: RuuviReactorChange<SensorSettings>) in }
        let secondSettingsToken = sut.observe(sensor) { (_: RuuviReactorChange<SensorSettings>) in }

        historyToken.invalidate()
        secondHistoryToken.invalidate()
        lastToken.invalidate()
        secondLastToken.invalidate()
        latestToken.invalidate()
        secondLatestToken.invalidate()
        settingsToken.invalidate()
        secondSettingsToken.invalidate()
    }

    func testTagSubjectCombineReportsInitialReadFailures() throws {
        let context = try makeBrokenSQLiteContext(dropping: RuuviTagSQLite.databaseTableName)
        let reporter = ErrorReporterSpy()

        _ = RuuviTagSubjectCombine(sqlite: context, errorReporter: reporter)

        XCTAssertEqual(reporter.errorCount, 1)
    }

    func testSensorSettingsCombineReportsInitialReadFailures() throws {
        let context = try makeBrokenSQLiteContext(dropping: SensorSettingsSQLite.databaseTableName)
        let reporter = ErrorReporterSpy()
        let sensor = makeUniqueSensor()

        _ = SensorSettingsCombine(
            luid: sensor.luid,
            macId: sensor.macId,
            sqlite: context,
            errorReporter: reporter
        )

        XCTAssertEqual(reporter.errorCount, 1)
    }

    func testRecordCombinesReportObservationFailures() async throws {
        let historyExpectation = expectation(description: "history observation error reported")
        let lastExpectation = expectation(description: "last observation error reported")
        let latestExpectation = expectation(description: "latest observation error reported")
        historyExpectation.assertForOverFulfill = false
        lastExpectation.assertForOverFulfill = false
        latestExpectation.assertForOverFulfill = false
        let sensor = makeUniqueSensor()

        let historyContext = try makeBrokenSQLiteContext(dropping: RuuviTagDataSQLite.databaseTableName)
        let historyReporter = ErrorReporterSpy(onReport: { _ in historyExpectation.fulfill() })
        let historyCombine = RuuviTagRecordSubjectCombine(
            luid: sensor.luid,
            macId: sensor.macId,
            sqlite: historyContext,
            errorReporter: historyReporter
        )

        let lastContext = try makeBrokenSQLiteContext(dropping: RuuviTagDataSQLite.databaseTableName)
        let lastReporter = ErrorReporterSpy(onReport: { _ in lastExpectation.fulfill() })
        let lastCombine = RuuviTagLastRecordSubjectCombine(
            luid: sensor.luid,
            macId: sensor.macId,
            sqlite: lastContext,
            errorReporter: lastReporter
        )

        let latestContext = try makeBrokenSQLiteContext(dropping: RuuviTagLatestDataSQLite.databaseTableName)
        let latestReporter = ErrorReporterSpy(onReport: { _ in latestExpectation.fulfill() })
        let latestCombine = RuuviTagLatestRecordSubjectCombine(
            luid: sensor.luid,
            macId: sensor.macId,
            sqlite: latestContext,
            errorReporter: latestReporter
        )

        historyCombine.start()
        lastCombine.start()
        latestCombine.start()

        await fulfillment(of: [historyExpectation, lastExpectation, latestExpectation], timeout: 2)
        XCTAssertGreaterThanOrEqual(historyReporter.errorCount, 1)
        XCTAssertGreaterThanOrEqual(lastReporter.errorCount, 1)
        XCTAssertGreaterThanOrEqual(latestReporter.errorCount, 1)
    }

    func testSettingsCombineReportsObservationFailures() async throws {
        let settingsExpectation = expectation(description: "settings observation error reported")
        settingsExpectation.assertForOverFulfill = false

        let settingsContext = makeSQLiteContext()
        let settingsReporter = ErrorReporterSpy(onReport: { _ in settingsExpectation.fulfill() })
        let sensor = makeUniqueSensor()
        let settingsCombine = SensorSettingsCombine(
            luid: sensor.luid,
            macId: sensor.macId,
            sqlite: settingsContext,
            errorReporter: settingsReporter
        )

        try dropTable(SensorSettingsSQLite.databaseTableName, in: settingsContext)

        await fulfillment(of: [settingsExpectation], timeout: 2)
        XCTAssertGreaterThanOrEqual(settingsReporter.errorCount, 1)
        _ = settingsCombine
    }

    func testObservePublishesInsertUpdateAndDeleteFromSQLiteChanges() async throws {
        let (sut, persistence) = try makeIntegratedReactor()
        let sensor = makeUniqueSensor(name: "Insertable")
        let inserted = expectation(description: "insert observed")
        let updated = expectation(description: "update observed")
        let deleted = expectation(description: "delete observed")
        let token = sut.observe { change in
            switch change {
            case let .insert(observed) where observed.id == sensor.id:
                inserted.fulfill()
            case let .update(observed) where observed.id == sensor.id && observed.name == "Updated":
                updated.fulfill()
            case let .delete(observed) where observed.id == sensor.id:
                deleted.fulfill()
            default:
                break
            }
        }
        defer { token.invalidate() }

        _ = try await persistence.create(sensor)
        await fulfillment(of: [inserted], timeout: 2)

        let renamed = sensor.with(name: "Updated")
        _ = try await persistence.update(renamed)
        await fulfillment(of: [updated], timeout: 2)

        _ = try await persistence.delete(renamed)
        await fulfillment(of: [deleted], timeout: 2)
    }

    func testObserveRecordsPublishesGrowingHistoryForObservedLuid() async throws {
        let (sut, persistence) = try makeIntegratedReactor()
        let sensor = makeUniqueSensor()
        _ = try await persistence.create(sensor)
        let firstRecord = makeUniqueRecord(sensor: sensor, date: Date(timeIntervalSince1970: 1_700_000_100), measurementSequenceNumber: 1)
        let secondRecord = makeUniqueRecord(sensor: sensor, date: Date(timeIntervalSince1970: 1_700_000_200), measurementSequenceNumber: 2)
        let firstBatch = expectation(description: "first history batch")
        let secondBatch = expectation(description: "second history batch")
        let token = sut.observe(try XCTUnwrap(sensor.luid)) { records in
            if records.count == 1, records.last?.measurementSequenceNumber == 1 {
                firstBatch.fulfill()
            }
            if records.count == 2, records.last?.measurementSequenceNumber == 2 {
                secondBatch.fulfill()
            }
        }
        defer { token.invalidate() }

        _ = try await persistence.create(firstRecord)
        await fulfillment(of: [firstBatch], timeout: 2)

        _ = try await persistence.create(secondRecord)
        await fulfillment(of: [secondBatch], timeout: 2)
    }

    func testObserveLastAndLatestPublishNewerDatabaseRows() async throws {
        let (sut, persistence) = try makeIntegratedReactor()
        let sensor = makeUniqueSensor()
        _ = try await persistence.create(sensor)
        let initial = makeUniqueRecord(sensor: sensor, date: Date(timeIntervalSince1970: 1_700_000_300), measurementSequenceNumber: 3)
        let older = makeUniqueRecord(sensor: sensor, date: Date(timeIntervalSince1970: 1_700_000_200), measurementSequenceNumber: 2)
        let newer = makeUniqueRecord(sensor: sensor, date: Date(timeIntervalSince1970: 1_700_000_400), measurementSequenceNumber: 4)
        let lastExpectation = expectation(description: "last record observed")
        let latestSeedExpectation = expectation(description: "latest seed observed")
        let latestExpectation = expectation(description: "latest record observed")
        let olderIgnored = expectation(description: "older latest record ignored")
        olderIgnored.isInverted = true
        let fulfillmentLock = NSLock()
        var fulfilledExpectations = Set<String>()

        func fulfillOnce(_ key: String, expectation: XCTestExpectation) {
            fulfillmentLock.lock()
            defer { fulfillmentLock.unlock() }
            guard fulfilledExpectations.insert(key).inserted else { return }
            expectation.fulfill()
        }

        let lastToken = sut.observeLast(sensor) { change in
            guard case let .update(record) = change,
                  record?.measurementSequenceNumber == 3 else { return }
            fulfillOnce("last-seed", expectation: lastExpectation)
        }
        let latestToken = sut.observeLatest(sensor) { change in
            guard case let .update(record) = change,
                  let sequence = record?.measurementSequenceNumber else { return }
            if sequence == 3 {
                fulfillOnce("latest-seed", expectation: latestSeedExpectation)
            }
            if sequence == 2 {
                fulfillOnce("older-ignored", expectation: olderIgnored)
            }
            if sequence == 4 {
                fulfillOnce("latest-newer", expectation: latestExpectation)
            }
        }
        defer {
            lastToken.invalidate()
            latestToken.invalidate()
        }

        _ = try await persistence.create(initial)
        await fulfillment(of: [lastExpectation], timeout: 2)

        _ = try await persistence.createLast(initial)
        await fulfillment(of: [latestSeedExpectation], timeout: 2)

        _ = try await persistence.updateLast(older)
        await fulfillment(of: [olderIgnored], timeout: 0.3)

        _ = try await persistence.updateLast(newer)
        await fulfillment(of: [latestExpectation], timeout: 2)
    }

    func testObserveSensorSettingsPublishesInsertUpdateAndDelete() async throws {
        let (sut, persistence) = try makeIntegratedReactor()
        let sensor = makeUniqueSensor()
        _ = try await persistence.create(sensor)
        let inserted = expectation(description: "settings inserted")
        let updated = expectation(description: "settings updated")
        let deleted = expectation(description: "settings deleted")
        let token = sut.observe(sensor) { change in
            switch change {
            case let .insert(settings) where settings.temperatureOffset == 1:
                inserted.fulfill()
            case let .update(settings) where settings.temperatureOffset == 2:
                updated.fulfill()
            case .delete:
                deleted.fulfill()
            default:
                break
            }
        }
        defer { token.invalidate() }

        let initialSettings = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: 1,
            humidityOffset: nil,
            pressureOffset: nil
        )
        _ = try await persistence.save(sensorSettings: initialSettings)
        await fulfillment(of: [inserted], timeout: 2)

        let updatedSettings = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: 2,
            humidityOffset: nil,
            pressureOffset: nil
        )
        _ = try await persistence.save(sensorSettings: updatedSettings)
        await fulfillment(of: [updated], timeout: 2)

        _ = try await persistence.deleteSensorSettings(sensor)
        await fulfillment(of: [deleted], timeout: 2)
    }
}

private func makeReactor(persistence: PersistenceSpy) -> RuuviReactorImpl {
    RuuviReactorImpl(
        sqliteContext: makeSQLiteContext(),
        sqlitePersistence: persistence,
        errorReporter: ErrorReporterSpy()
    )
}

private func makeIntegratedReactor() throws -> (RuuviReactorImpl, RuuviPersistenceSQLite) {
    let context = makeSQLiteContext()
    let persistence = RuuviPersistenceSQLite(context: context)
    let reactor = RuuviReactorImpl(
        sqliteContext: context,
        sqlitePersistence: persistence,
        errorReporter: ErrorReporterSpy()
    )
    return (reactor, persistence)
}

private func makeSQLiteContext() -> SQLiteContext {
    let database = try! SQLiteGRDBDatabase(path: temporaryDatabasePath())
    let context = SQLiteContextGRDB(database: database)
    context.database.migrateIfNeeded()
    return context
}

private func makeBrokenSQLiteContext(dropping tableName: String) throws -> SQLiteContext {
    let context = makeSQLiteContext()
    try dropTable(tableName, in: context)
    return context
}

private func dropTable(_ tableName: String, in context: SQLiteContext) throws {
    try context.database.dbPool.write { db in
        try db.drop(table: tableName)
    }
}

private func temporaryDatabasePath() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("RuuviReactorTests-\(UUID().uuidString).sqlite")
        .path
}

private final class PersistenceSpy: RuuviPersistence {
    var readAllSensors: [AnyRuuviTagSensor] = []
    var readAllError: Error?
    var lastRecord: RuuviTagSensorRecord?
    var latestRecord: RuuviTagSensorRecord?
    var sensorSettings: SensorSettings?

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
        return readAllSensors
    }

    func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ ruuviTagId: String, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ ruuviTagId: String, after date: Date) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTagId: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { lastRecord }
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { latestRecord }
    func deleteLatest(_ ruuviTagId: String) async throws -> Bool { true }
    func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor { readAllSensors.first ?? makeSensor().any }
    func getStoredTagsCount() async throws -> Int { readAllSensors.count }
    func getStoredMeasurementsCount() async throws -> Int { 0 }
    func read(_ ruuviTagId: String, after date: Date, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readDownsampled(_ ruuviTagId: String, after date: Date, with intervalMinutes: Int, pick points: Double) async throws -> [RuuviTagSensorRecord] { [] }
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? { sensorSettings }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        sensorSettings ?? SensorSettingsStruct(
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
        sensorSettings ?? SensorSettingsStruct(
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
        sensorSettings ?? SensorSettingsStruct(
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
    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for key: String) async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for type: RuuviCloudQueuedRequestType) async throws -> [RuuviCloudQueuedRequest] { [] }
    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool { true }
    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool { true }
    func deleteQueuedRequests() async throws -> Bool { true }
    func save(subscription: CloudSensorSubscription) async throws -> CloudSensorSubscription { subscription }
    func readSensorSubscriptionSettings(_ ruuviTag: RuuviTagSensor) async throws -> CloudSensorSubscription? { nil }
}

private final class ErrorReporterSpy: RuuviErrorReporter {
    private let lock = NSLock()
    private var errors: [Error] = []
    private let onReport: ((Error) -> Void)?

    init(onReport: ((Error) -> Void)? = nil) {
        self.onReport = onReport
    }

    func report(error: Error) {
        lock.lock()
        errors.append(error)
        lock.unlock()
        onReport?(error)
    }

    var errorCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return errors.count
    }
}

private struct UnexpectedPersistenceError: Error {}

private func makeSensor(
    macId: String = "AA:BB:CC:11:22:33",
    luid: String = "luid-1",
    name: String = "Sensor"
) -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: luid.luid,
        macId: macId.mac,
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

private func makeUniqueSensor(name: String = "Sensor") -> RuuviTagSensor {
    let hex = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    let mac = stride(from: 0, to: 12, by: 2).map { index in
        let start = hex.index(hex.startIndex, offsetBy: index)
        let end = hex.index(start, offsetBy: 2)
        return String(hex[start..<end]).uppercased()
    }.joined(separator: ":")

    return makeSensor(
        macId: mac,
        luid: "luid-\(UUID().uuidString)",
        name: name
    )
}

private func makeRecord(macId: String, luid: String) -> RuuviTagSensorRecord {
    RuuviTagSensorRecordStruct(
        luid: luid.luid,
        date: Date(timeIntervalSince1970: 1_700_000_000),
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
        measurementSequenceNumber: 1,
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

private func makeUniqueRecord(
    sensor: RuuviTagSensor,
    date: Date,
    measurementSequenceNumber: Int
) -> RuuviTagSensorRecord {
    RuuviTagSensorRecordStruct(
        luid: sensor.luid,
        date: date,
        source: .advertisement,
        macId: sensor.macId,
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
