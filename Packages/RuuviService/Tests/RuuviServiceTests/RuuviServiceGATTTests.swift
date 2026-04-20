@testable import RuuviService
@testable import BTKit
import RuuviOntology
import RuuviPool
import XCTest

final class RuuviServiceGATTTests: XCTestCase {
    func testQueueSyncLogsCreatesOperationAndReturnsTrue() async throws {
        let queue = OperationQueueSpy()
        var capturedFactoryInput: (
            uuid: String,
            mac: String?,
            firmware: Int,
            from: Date,
            settings: SensorSettings?,
            connectionTimeout: TimeInterval?,
            serviceTimeout: TimeInterval?
        )?
        let operation = FakeReadLogsOperation(uuid: "luid-1")
        queue.onAddOperation = { addedOperation in
            addedOperation.completionBlock?()
        }
        let sut = GATTServiceQueue(
            queue: queue,
            operationFactory: { uuid, mac, firmware, from, settings, _, connectionTimeout, serviceTimeout in
                capturedFactoryInput = (
                    uuid: uuid,
                    mac: mac,
                    firmware: firmware,
                    from: from,
                    settings: settings,
                    connectionTimeout: connectionTimeout,
                    serviceTimeout: serviceTimeout
                )
                return operation
            }
        )
        let from = Date(timeIntervalSince1970: 123)

        let result = try await sut.syncLogs(
            uuid: "luid-1",
            mac: "AA:BB:CC:11:22:33",
            firmware: 6,
            from: from,
            settings: nil,
            progress: nil,
            connectionTimeout: 12,
            serviceTimeout: 34
        )

        XCTAssertTrue(result)
        XCTAssertEqual(queue.addedOperations.count, 1)
        XCTAssertEqual(capturedFactoryInput?.uuid, "luid-1")
        XCTAssertEqual(capturedFactoryInput?.mac, "AA:BB:CC:11:22:33")
        XCTAssertEqual(capturedFactoryInput?.firmware, 6)
        XCTAssertEqual(capturedFactoryInput?.from, from)
        XCTAssertEqual(capturedFactoryInput?.connectionTimeout, 12)
        XCTAssertEqual(capturedFactoryInput?.serviceTimeout, 34)
    }

    func testQueuePublicInitializerCreatesReadLogsOperationAndConfiguresQueue() async throws {
        let sut = GATTServiceQueue(
            ruuviPool: PoolSpy(),
            background: .shared
        )
        XCTAssertEqual(sut.queue.maxConcurrentOperationCount, 3)

        let queue = OperationQueueSpy()
        queue.onAddOperation = { addedOperation in
            addedOperation.completionBlock?()
        }
        sut.queue = queue

        let result = try await sut.syncLogs(
            uuid: "luid-1",
            mac: "AA:BB:CC:11:22:33",
            firmware: 6,
            from: Date(timeIntervalSince1970: 123),
            settings: nil,
            progress: nil,
            connectionTimeout: 12,
            serviceTimeout: 34
        )

        XCTAssertTrue(result)
        XCTAssertEqual(queue.addedOperations.count, 1)
        guard let operation = queue.addedOperations.first as? RuuviTagReadLogsOperable else {
            return XCTFail("Expected a read logs operation")
        }
        XCTAssertEqual(operation.uuid, "luid-1")
        XCTAssertTrue(queue.addedOperations.first is RuuviTagReadLogsOperation)
    }

    func testMakeBackgroundLogReaderMapsServicesOptionsAndBTKitResponses() {
        let operation = makeReadLogsOperation()
        let from = Date(timeIntervalSince1970: 123)
        let progress: (BTServiceProgress) -> Void = { _ in }
        var capturedUUIDs: [String] = []
        var capturedDates: [Date] = []
        var capturedServices: [BTRuuviNUSService] = []
        var capturedOptions: [BTScannerOptionsInfo?] = []
        var capturedObserverIDs: [ObjectIdentifier] = []
        var results: [RuuviTagReadLogsCallbackResult] = []
        let sut = RuuviTagReadLogsOperation.makeLogReader { observer, uuid, from, service, options, progress, result in
            capturedUUIDs.append(uuid)
            capturedDates.append(from)
            capturedServices.append(service)
            capturedOptions.append(options)
            capturedObserverIDs.append(ObjectIdentifier(observer))
            XCTAssertNotNil(progress)

            switch capturedServices.count {
            case 1:
                result(observer, .success(.points(4)))
            case 2:
                result(observer, .success(.logs([])))
            default:
                result(observer, .failure(.logic(.serviceTimedOut)))
            }
        }

        sut(
            operation,
            RuuviTagReadLogsRequestContext(
                uuid: "luid-1",
                from: from,
                service: .e1,
                progress: progress,
                connectionTimeout: 11,
                serviceTimeout: 22
            )
        ) {
            results.append($0)
        }
        sut(
            operation,
            RuuviTagReadLogsRequestContext(
                uuid: "luid-1",
                from: from,
                service: .all,
                progress: progress,
                connectionTimeout: 11,
                serviceTimeout: 22
            )
        ) {
            results.append($0)
        }
        sut(
            operation,
            RuuviTagReadLogsRequestContext(
                uuid: "luid-1",
                from: from,
                service: .e1,
                progress: progress,
                connectionTimeout: 11,
                serviceTimeout: 22
            )
        ) {
            results.append($0)
        }

        XCTAssertEqual(capturedUUIDs, ["luid-1", "luid-1", "luid-1"])
        XCTAssertEqual(capturedDates, [from, from, from])
        XCTAssertEqual(capturedObserverIDs, [ObjectIdentifier(operation), ObjectIdentifier(operation), ObjectIdentifier(operation)])
        XCTAssertEqual(capturedOptions.count, 3)
        for options in capturedOptions {
            let parsedOptions = BTKitParsedOptionsInfo(options)
            switch parsedOptions.callbackQueue {
            case .untouch:
                break
            default:
                XCTFail("Expected untouch callback queue")
            }
            XCTAssertEqual(parsedOptions.connectionTimeout, 11)
            XCTAssertEqual(parsedOptions.serviceTimeout, 22)
        }
        XCTAssertEqual(results.count, 3)
        guard case .points(4) = results[0] else {
            return XCTFail("Expected points result")
        }
        guard case .logs(let logs) = results[1], logs.isEmpty else {
            return XCTFail("Expected logs result")
        }
        guard case let .failure(error) = results[2],
              case let .logic(logicError) = error,
              case .serviceTimedOut = logicError else {
            return XCTFail("Expected BT timeout failure")
        }
        XCTAssertEqual(capturedServices.count, 3)
        if case .e1 = capturedServices[0] {} else {
            XCTFail("Expected e1 service")
        }
        if case .all = capturedServices[1] {} else {
            XCTFail("Expected all service")
        }
        if case .e1 = capturedServices[2] {} else {
            XCTFail("Expected e1 service")
        }
    }

    func testMakeBackgroundDisconnectHandlerForwardsObserverAndUUID() {
        let operation = makeReadLogsOperation()
        var capturedObserverID: ObjectIdentifier?
        var capturedUUID: String?
        let sut = RuuviTagReadLogsOperation.makeDisconnectHandler { observer, uuid in
            capturedObserverID = ObjectIdentifier(observer)
            capturedUUID = uuid
        }

        sut(operation, "luid-1")

        XCTAssertEqual(capturedObserverID, ObjectIdentifier(operation))
        XCTAssertEqual(capturedUUID, "luid-1")
    }

    func testMakeRecordsSaverDelegatesToPoolCreateRecords() async throws {
        let pool = PoolSpy()
        let records = [makeRecord(luid: "luid-1", macId: "AA:BB:CC:11:22:33")]

        let result = try await RuuviTagReadLogsOperation.makeRecordsSaver(ruuviPool: pool)(records)

        XCTAssertTrue(result)
        XCTAssertEqual(pool.createdRecords.count, 1)
        XCTAssertEqual(pool.createdRecords.first?.luid?.value, "luid-1")
        XCTAssertEqual(pool.createdRecords.first?.macId?.value, "AA:BB:CC:11:22:33")
    }

    func testQueueRejectsDuplicateSyncForSameUUID() async {
        let queue = OperationQueueSpy()
        queue.stubbedOperations = [FakeReadLogsOperation(uuid: "luid-1")]
        let sut = GATTServiceQueue(
            queue: queue,
            operationFactory: { _, _, _, _, _, _, _, _ in
                FakeReadLogsOperation(uuid: "other")
            }
        )

        do {
            _ = try await sut.syncLogs(
                uuid: "luid-1",
                mac: nil,
                firmware: 5,
                from: Date(),
                settings: nil,
                progress: nil,
                connectionTimeout: nil,
                serviceTimeout: nil
            )
            XCTFail("Expected duplicate sync error")
        } catch let error as RuuviServiceError {
            guard case .isAlreadySyncingLogsWithThisTag = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testQueueSyncLogsPropagatesOperationErrorFromCompletionBlock() async {
        let queue = OperationQueueSpy()
        let operation = FakeReadLogsOperation(uuid: "luid-1")
        operation.error = .btkit(.logic(.serviceTimedOut))
        queue.onAddOperation = { addedOperation in
            addedOperation.completionBlock?()
        }
        let sut = GATTServiceQueue(
            queue: queue,
            operationFactory: { _, _, _, _, _, _, _, _ in
                operation
            }
        )

        do {
            _ = try await sut.syncLogs(
                uuid: "luid-1",
                mac: nil,
                firmware: 5,
                from: Date(),
                settings: nil,
                progress: nil,
                connectionTimeout: nil,
                serviceTimeout: nil
            )
            XCTFail("Expected read logs error")
        } catch let error as RuuviServiceError {
            guard case let .btkit(btError) = error,
                  case let .logic(logicError) = btError,
                  case .serviceTimedOut = logicError else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testQueueIsSyncingLogsMatchesOperationsByUUID() {
        let queued = FakeReadLogsOperation(uuid: "queued")
        let queue = OperationQueueSpy()
        queue.stubbedOperations = [queued]
        let sut = GATTServiceQueue(
            queue: queue,
            operationFactory: { _, _, _, _, _, _, _, _ in
                FakeReadLogsOperation(uuid: "unused")
            }
        )

        XCTAssertTrue(sut.isSyncingLogs(with: "queued"))
        XCTAssertFalse(sut.isSyncingLogs(with: "missing"))
    }

    func testQueueReportsQueuedStateOnlyForPendingOperations() {
        let queued = FakeReadLogsOperation(uuid: "queued")
        let executing = FakeReadLogsOperation(uuid: "executing")
        executing.state = .executing
        let finished = FakeReadLogsOperation(uuid: "finished")
        finished.state = .finished
        let queue = OperationQueueSpy()
        queue.stubbedOperations = [queued, executing, finished]
        let sut = GATTServiceQueue(
            queue: queue,
            operationFactory: { _, _, _, _, _, _, _, _ in
                FakeReadLogsOperation(uuid: "unused")
            }
        )

        XCTAssertTrue(sut.isSyncingLogsQueued(with: "queued"))
        XCTAssertFalse(sut.isSyncingLogsQueued(with: "executing"))
        XCTAssertFalse(sut.isSyncingLogsQueued(with: "finished"))
        XCTAssertFalse(sut.isSyncingLogsQueued(with: "missing"))
    }

    func testQueueStopGattSyncStopsAndCancelsOperation() async throws {
        let operation = FakeReadLogsOperation(uuid: "luid-1")
        let queue = OperationQueueSpy()
        queue.stubbedOperations = [operation]
        let sut = GATTServiceQueue(
            queue: queue,
            operationFactory: { _, _, _, _, _, _, _, _ in
                FakeReadLogsOperation(uuid: "unused")
            }
        )

        let stopped = try await sut.stopGattSync(for: "luid-1")

        XCTAssertTrue(stopped)
        XCTAssertTrue(operation.stopSyncCalled)
        XCTAssertTrue(operation.isCancelled)
    }

    func testQueueStopGattSyncReturnsFalseWhenOperationIsMissing() async throws {
        let sut = GATTServiceQueue(
            queue: OperationQueueSpy(),
            operationFactory: { _, _, _, _, _, _, _, _ in
                FakeReadLogsOperation(uuid: "unused")
            }
        )

        let stopped = try await sut.stopGattSync(for: "missing")

        XCTAssertFalse(stopped)
    }

    func testReadLogsOperationUsesE1ServicePostsProgressAndFinishes() {
        let started = expectation(forNotification: .RuuviTagReadLogsOperationDidStart, object: nil)
        let progress = expectation(forNotification: .RuuviTagReadLogsOperationProgress, object: nil) { notification in
            let uuid = notification.userInfo?[RuuviTagReadLogsOperationProgressKey.uuid] as? String
            let points = notification.userInfo?[RuuviTagReadLogsOperationProgressKey.progress] as? Int
            XCTAssertEqual(uuid, "luid-1")
            XCTAssertEqual(points, 7)
            return true
        }
        let finished = expectation(forNotification: .RuuviTagReadLogsOperationDidFinish, object: nil) { notification in
            let uuid = notification.userInfo?[RuuviTagReadLogsOperationDidFinishKey.uuid] as? String
            XCTAssertEqual(uuid, "luid-1")
            return true
        }
        var capturedContext: RuuviTagReadLogsRequestContext?
        let savedRecords = SensorRecordsBox()
        let sut = RuuviTagReadLogsOperation(
            uuid: "luid-1",
            mac: "AA:BB:CC:11:22:33",
            firmware: 6,
            from: Date(timeIntervalSince1970: 100),
            settings: nil,
            progress: nil,
            connectionTimeout: 11,
            serviceTimeout: 22,
            logReader: { _, context, completion in
                capturedContext = context
                completion(.points(7))
                completion(.logs([]))
            },
            disconnect: { _, _ in },
            saveRecords: { records in
                savedRecords.set(records)
                return true
            },
            logMapper: { _, uuid, mac in
                [makeRecord(luid: uuid, macId: mac)]
            }
        )

        sut.start()

        wait(for: [started, progress, finished], timeout: 1)
        XCTAssertEqual(capturedContext?.service, .e1)
        XCTAssertEqual(capturedContext?.connectionTimeout, 11)
        XCTAssertEqual(capturedContext?.serviceTimeout, 22)
        let persistedRecords = savedRecords.records
        XCTAssertEqual(persistedRecords.count, 1)
        XCTAssertEqual(persistedRecords.first?.luid?.value, "luid-1")
        XCTAssertEqual(persistedRecords.first?.macId?.value, "AA:BB:CC:11:22:33")
        XCTAssertEqual(sut.state, AsyncOperation.State.finished)
    }

    func testReadLogsOperationUsesAllServiceForLegacyFirmware() {
        var capturedContext: RuuviTagReadLogsRequestContext?
        let finished = expectation(forNotification: .RuuviTagReadLogsOperationDidFinish, object: nil)
        let sut = RuuviTagReadLogsOperation(
            uuid: "luid-1",
            mac: nil,
            firmware: 5,
            from: Date(),
            settings: nil,
            logReader: { _, context, completion in
                capturedContext = context
                completion(.logs([]))
            },
            disconnect: { _, _ in },
            saveRecords: { _ in true },
            logMapper: { _, _, _ in [] }
        )

        sut.start()

        wait(for: [finished], timeout: 1)
        XCTAssertEqual(capturedContext?.service, .all)
    }

    func testReadLogsOperationDefaultsNilTimeoutsAndMapsLogsWithDefaultMapper() {
        var capturedContext: RuuviTagReadLogsRequestContext?
        let finished = expectation(forNotification: .RuuviTagReadLogsOperationDidFinish, object: nil)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let log = RuuviTagEnvLogFull(
            date: date,
            temperature: 21.5,
            humidity: 42,
            pressure: 1008,
            pm1: 1,
            pm25: 2,
            pm4: 3,
            pm10: 4,
            co2: 600,
            voc: 120,
            nox: 80,
            luminosity: 150,
            soundInstant: 50,
            soundAvg: 55,
            soundPeak: 60,
            batteryVoltage: 2.9,
            measurementSequenceNumber: 44
        )
        let savedRecords = SensorRecordsBox()
        let sut = RuuviTagReadLogsOperation(
            uuid: "luid-default",
            mac: "AA:BB:CC:11:22:33",
            firmware: 6,
            from: Date(timeIntervalSince1970: 100),
            settings: nil,
            progress: nil,
            connectionTimeout: nil,
            serviceTimeout: nil,
            logReader: { _, context, completion in
                capturedContext = context
                completion(.logs([log]))
            },
            disconnect: { _, _ in },
            saveRecords: { records in
                savedRecords.set(records)
                return true
            },
            logMapper: RuuviTagReadLogsOperation.defaultLogMapper
        )

        sut.start()

        wait(for: [finished], timeout: 1)
        XCTAssertEqual(capturedContext?.connectionTimeout, 0)
        XCTAssertEqual(capturedContext?.serviceTimeout, 0)
        let record = savedRecords.records.first
        XCTAssertEqual(record?.luid?.value, "luid-default")
        XCTAssertEqual(record?.macId?.value, "AA:BB:CC:11:22:33")
        XCTAssertEqual(record?.source, .log)
        XCTAssertEqual(record?.date, date)
        XCTAssertEqual(record?.temperature?.value, 21.5)
        XCTAssertEqual(record?.measurementSequenceNumber, 44)
    }

    func testReadLogsOperationMapsPoolErrorsAndPostsFailure() {
        let failed = expectation(forNotification: .RuuviTagReadLogsOperationDidFail, object: nil) { notification in
            let uuid = notification.userInfo?[RuuviTagReadLogsOperationDidFailKey.uuid] as? String
            XCTAssertEqual(uuid, "luid-1")
            return true
        }
        let sut = RuuviTagReadLogsOperation(
            uuid: "luid-1",
            mac: nil,
            firmware: 5,
            from: Date(),
            settings: nil,
            logReader: { _, _, completion in
                completion(.logs([]))
            },
            disconnect: { _, _ in },
            saveRecords: { _ in
                throw RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
            },
            logMapper: { _, _, _ in [makeRecord()] }
        )

        sut.start()

        wait(for: [failed], timeout: 1)
        guard case let .ruuviPool(poolError) = sut.error,
              case let .ruuviPersistence(persistenceError) = poolError,
              case .failedToFindRuuviTag = persistenceError else {
            return XCTFail("Unexpected error: \(String(describing: sut.error))")
        }
        XCTAssertEqual(sut.state, AsyncOperation.State.finished)
    }

    func testReadLogsOperationWrapsUnexpectedSaveErrorsAsGRDBFailures() {
        let failed = expectation(forNotification: .RuuviTagReadLogsOperationDidFail, object: nil)
        let sut = RuuviTagReadLogsOperation(
            uuid: "luid-1",
            mac: nil,
            firmware: 5,
            from: Date(),
            settings: nil,
            logReader: { _, _, completion in
                completion(.logs([]))
            },
            disconnect: { _, _ in },
            saveRecords: { _ in
                throw TestGATTError.sample
            },
            logMapper: { _, _, _ in [makeRecord()] }
        )

        sut.start()

        wait(for: [failed], timeout: 1)
        guard case let .ruuviPool(poolError) = sut.error,
              case let .ruuviPersistence(persistenceError) = poolError,
              case let .grdb(error) = persistenceError,
              error is TestGATTError else {
            return XCTFail("Unexpected error: \(String(describing: sut.error))")
        }
        XCTAssertEqual(sut.state, AsyncOperation.State.finished)
    }

    func testReadLogsOperationMapsBTFailureAndStopSyncDisconnects() {
        let failed = expectation(forNotification: .RuuviTagReadLogsOperationDidFail, object: nil)
        var disconnectedUUID: String?
        let sut = RuuviTagReadLogsOperation(
            uuid: "luid-1",
            mac: nil,
            firmware: 5,
            from: Date(),
            settings: nil,
            logReader: { _, _, completion in
                completion(.failure(.logic(.serviceTimedOut)))
            },
            disconnect: { _, uuid in
                disconnectedUUID = uuid
            },
            saveRecords: { _ in true },
            logMapper: { _, _, _ in [] }
        )

        sut.start()
        wait(for: [failed], timeout: 1)
        sut.stopSync()

        guard case let .btkit(btError) = sut.error,
              case let .logic(logicError) = btError,
              case .serviceTimedOut = logicError else {
            return XCTFail("Unexpected error: \(String(describing: sut.error))")
        }
        XCTAssertEqual(disconnectedUUID, "luid-1")
        XCTAssertEqual(sut.state, .finished)
    }
}

private enum TestGATTError: Error {
    case sample
}

private func makeReadLogsOperation(
    uuid: String = "luid-1"
) -> RuuviTagReadLogsOperation {
    RuuviTagReadLogsOperation(
        uuid: uuid,
        mac: nil,
        firmware: 5,
        from: Date(),
        settings: nil,
        logReader: { _, _, _ in },
        disconnect: { _, _ in },
        saveRecords: { _ in true },
        logMapper: { _, _, _ in [] }
    )
}

private final class FakeReadLogsOperation: AsyncOperation, RuuviTagReadLogsOperable, @unchecked Sendable {
    let uuid: String
    var error: RuuviServiceError?
    var stopSyncCalled = false

    init(uuid: String) {
        self.uuid = uuid
        super.init()
    }

    override func main() {}

    func stopSync() {
        stopSyncCalled = true
    }
}

private final class OperationQueueSpy: OperationQueue, @unchecked Sendable {
    var stubbedOperations: [Operation] = []
    var addedOperations: [Operation] = []
    var onAddOperation: ((Operation) -> Void)?

    override var operations: [Operation] {
        stubbedOperations + addedOperations
    }

    override func addOperation(_ op: Operation) {
        addedOperations.append(op)
        onAddOperation?(op)
    }
}

private final class SensorRecordsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [RuuviTagSensorRecord] = []

    var records: [RuuviTagSensorRecord] {
        lock.withLock { storage }
    }

    func set(_ records: [RuuviTagSensorRecord]) {
        lock.withLock {
            storage = records
        }
    }
}
