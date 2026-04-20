@testable import RuuviDaemon
import BTKit
import BackgroundTasks
import RuuviCloud
import RuuviLocal
import RuuviNotification
import RuuviNotifier
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviReactor
import RuuviService
import RuuviStorage
import XCTest

final class RuuviDaemonStatefulTests: XCTestCase {
    func testWorkerRunsBlockOnDedicatedThreadAndStopCancelsIt() async throws {
        let sut = InspectingWorker()
        let started = expectation(description: "worker block executed")

        sut.start {
            sut.executedOnThread = Thread.current
            started.fulfill()
        }

        await fulfillment(of: [started], timeout: 1)
        let thread = try XCTUnwrap(sut.thread)
        XCTAssertEqual(sut.executedOnThread, thread)
        XCTAssertNotNil(thread.name)

        sut.stopWork()
        waitForThreadCancellation(thread)
        XCTAssertTrue(thread.isCancelled)
    }

    func testCloudSyncWorkerRefreshImmediatelyTriggersSyncWhenMigrationIsOff() async {
        let syncExpectation = expectation(description: "sync all records")
        let service = CloudSyncServiceSpy()
        service.onSyncAllRecords = {
            syncExpectation.fulfill()
        }
        let sut = makeCloudSyncWorker(
            settings: SettingsStub(signalVisibilityMigrationInProgress: false),
            service: service
        )

        sut.refreshImmediately()

        await fulfillment(of: [syncExpectation], timeout: 1)
        XCTAssertEqual(service.syncAllRecordsCalls, 1)
    }

    func testCloudSyncWorkerDefaultExecutorRunsImmediateRefresh() async {
        let syncExpectation = expectation(description: "sync all records with default executor")
        let service = CloudSyncServiceSpy()
        service.onSyncAllRecords = {
            syncExpectation.fulfill()
        }
        let sut = RuuviDaemonCloudSyncWorker(
            localSettings: SettingsStub(signalVisibilityMigrationInProgress: false),
            localSyncState: LocalSyncStateStub(),
            cloudSyncService: service
        )

        sut.refreshImmediately()

        await fulfillment(of: [syncExpectation], timeout: 1)
        XCTAssertEqual(service.syncAllRecordsCalls, 1)
    }

    func testCloudSyncWorkerDefaultDelayedExecutorRunsScheduledWork() async {
        let scheduled = expectation(description: "delayed executor runs work")

        let item = RuuviDaemonCloudSyncWorker.defaultDelayedWorkExecutor(delay: 0.01) {
            scheduled.fulfill()
        }

        await fulfillment(of: [scheduled], timeout: 1)
        XCTAssertFalse(item.isCancelled)
    }

    func testCloudSyncWorkerStopBeforeStartIsNoOp() {
        let sut = RuuviDaemonCloudSyncWorker(
            localSettings: SettingsStub(signalVisibilityMigrationInProgress: false),
            localSyncState: LocalSyncStateStub(),
            cloudSyncService: CloudSyncServiceSpy()
        )

        sut.stop()

        XCTAssertFalse(sut.isRunning())
        XCTAssertNil(sut.thread)
    }

    func testCloudSyncWorkerRefreshLatestRecordSkipsWhileMigrationIsRunning() async {
        let service = CloudSyncServiceSpy()
        let sut = makeCloudSyncWorker(
            settings: SettingsStub(signalVisibilityMigrationInProgress: true),
            service: service
        )

        sut.refreshLatestRecord()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(service.refreshLatestRecordCalls, 0)
    }

    func testCloudSyncWorkerRefreshLatestRecordTriggersServiceWhenMigrationIsOff() async {
        let refreshExpectation = expectation(description: "latest record refresh")
        let service = CloudSyncServiceSpy()
        service.onRefreshLatestRecord = {
            refreshExpectation.fulfill()
        }
        let sut = makeCloudSyncWorker(
            settings: SettingsStub(signalVisibilityMigrationInProgress: false),
            service: service
        )

        sut.refreshLatestRecord()

        await fulfillment(of: [refreshExpectation], timeout: 1)
        XCTAssertEqual(service.refreshLatestRecordCalls, 1)
    }

    func testCloudSyncWorkerSchedulesSingleDeferredRefreshDuringMigration() async {
        let syncExpectation = expectation(description: "deferred sync executed")
        let service = CloudSyncServiceSpy()
        service.onSyncAllRecords = {
            syncExpectation.fulfill()
        }
        var settings = SettingsStub(signalVisibilityMigrationInProgress: true)
        var delayedItems: [DispatchWorkItem] = []
        let sut = RuuviDaemonCloudSyncWorker(
            localSettings: settings,
            localSyncState: LocalSyncStateStub(),
            cloudSyncService: service,
            workExecutor: { work in work() },
            delayedWorkExecutor: { _, work in
                let item = DispatchWorkItem(block: work)
                delayedItems.append(item)
                return item
            }
        )

        sut.refreshImmediately()
        sut.refreshImmediately()

        XCTAssertEqual(service.syncAllRecordsCalls, 0)
        XCTAssertEqual(delayedItems.count, 1)

        settings.signalVisibilityMigrationInProgress = false
        delayedItems[0].perform()

        await fulfillment(of: [syncExpectation], timeout: 1)
        XCTAssertEqual(service.syncAllRecordsCalls, 1)
    }

    func testCloudSyncWorkerStartMarksRunningAndStopCancelsThread() async {
        let syncExpectation = expectation(description: "initial sync executed")
        let service = CloudSyncServiceSpy()
        service.onSyncAllRecords = {
            syncExpectation.fulfill()
        }
        let sut = RuuviDaemonCloudSyncWorker(
            localSettings: SettingsStub(signalVisibilityMigrationInProgress: false),
            localSyncState: LocalSyncStateStub(),
            cloudSyncService: service,
            workExecutor: { work in work() }
        )

        sut.start()

        await fulfillment(of: [syncExpectation], timeout: 1)
        XCTAssertTrue(sut.isRunning())
        let thread = try? XCTUnwrap(sut.thread)

        sut.stop()

        if let thread {
            waitForThreadCancellation(thread)
            XCTAssertTrue(thread.isCancelled)
        } else {
            XCTFail("Expected worker thread")
        }
        await waitUntil {
            !sut.isRunning()
        }
    }

    func testCloudSyncWorkerStopCancelsDeferredRefreshAfterMigration() async {
        let service = CloudSyncServiceSpy()
        var delayedItem: DispatchWorkItem?
        let sut = RuuviDaemonCloudSyncWorker(
            localSettings: SettingsStub(signalVisibilityMigrationInProgress: true),
            localSyncState: LocalSyncStateStub(),
            cloudSyncService: service,
            workExecutor: { work in work() },
            delayedWorkExecutor: { _, work in
                let item = DispatchWorkItem(block: work)
                delayedItem = item
                return item
            }
        )

        sut.start()
        await waitUntil {
            delayedItem != nil && sut.isRunning()
        }

        let thread = try? XCTUnwrap(sut.thread)
        sut.stop()

        if let thread {
            waitForThreadCancellation(thread)
            XCTAssertTrue(thread.isCancelled)
        } else {
            XCTFail("Expected worker thread")
        }
        XCTAssertTrue(delayedItem?.isCancelled == true)
        XCTAssertEqual(service.syncAllRecordsCalls, 0)
    }

    func testDataPruningManagerBuildsOneOperationPerStoredSensor() async throws {
        let storage = StorageSpy()
        storage.sensors = [makeSensor(id: "sensor-1").any, makeSensor(id: "sensor-2").any]
        let sut = DataPruningOperationsManager(
            settings: SettingsStub(dataPruningOffsetHours: 6),
            ruuviStorage: storage,
            ruuviPool: PoolSpy()
        )

        let operations = try await sut.ruuviTagPruningOperations()

        XCTAssertEqual(operations.count, 2)
        XCTAssertTrue(operations.allSatisfy { $0 is RuuviTagDataPruningOperation })
    }

    func testDataPruningManagerWrapsStorageErrors() async {
        let storage = StorageSpy()
        storage.readAllError = RuuviStorageError.ruuviPersistence(.failedToFindRuuviTag)
        let sut = DataPruningOperationsManager(
            settings: SettingsStub(),
            ruuviStorage: storage,
            ruuviPool: PoolSpy()
        )

        do {
            _ = try await sut.ruuviTagPruningOperations()
            XCTFail("Expected wrapped storage error")
        } catch let error as RuuviDaemonError {
            guard case let .ruuviStorage(storageError) = error,
                  case let .ruuviPersistence(persistenceError) = storageError,
                  case .failedToFindRuuviTag = persistenceError else {
                return XCTFail("Unexpected daemon error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDataPruningManagerWrapsUnexpectedStorageErrors() async {
        let storage = StorageSpy()
        storage.readAllError = TestError()
        let sut = DataPruningOperationsManager(
            settings: SettingsStub(),
            ruuviStorage: storage,
            ruuviPool: PoolSpy()
        )

        do {
            _ = try await sut.ruuviTagPruningOperations()
            XCTFail("Expected wrapped generic storage error")
        } catch let error as RuuviDaemonError {
            guard case let .ruuviStorage(storageError) = error,
                  case let .ruuviPersistence(persistenceError) = storageError,
                  case .grdb = persistenceError else {
                return XCTFail("Unexpected daemon error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPruningOperationDeletesRecordsBeforeComputedDateAndFinishes() async {
        let deleteExpectation = expectation(description: "records deleted")
        let pool = PoolSpy()
        pool.onDeleteAllRecordsBefore = { _, _ in
            deleteExpectation.fulfill()
        }
        let settings = SettingsStub(dataPruningOffsetHours: 12)
        let sut = RuuviTagDataPruningOperation(
            id: "sensor-1",
            ruuviPool: pool,
            settings: settings
        )
        let beforeStart = Date()

        sut.start()

        await fulfillment(of: [deleteExpectation], timeout: 1)
        waitForOperationToFinish(sut)
        XCTAssertEqual(pool.deletedRecordRequests.first?.id, "sensor-1")
        let expectedLowerBound = beforeStart.addingTimeInterval(-12 * 60 * 60 - 5)
        let expectedUpperBound = Date().addingTimeInterval(-12 * 60 * 60 + 5)
        if let deletedBeforeDate = pool.deletedRecordRequests.first?.date {
            XCTAssertGreaterThanOrEqual(deletedBeforeDate, expectedLowerBound)
            XCTAssertLessThanOrEqual(deletedBeforeDate, expectedUpperBound)
        } else {
            XCTFail("Expected pruning cutoff date")
        }
        XCTAssertTrue(sut.isFinished)
        XCTAssertEqual(sut.state, .finished)
    }

    func testPruningOperationFinishesWhenDeleteFails() async {
        let pool = PoolSpy()
        pool.deleteAllRecordsBeforeError = TestError()
        let sut = RuuviTagDataPruningOperation(
            id: "sensor-1",
            ruuviPool: pool,
            settings: SettingsStub(dataPruningOffsetHours: 1)
        )

        sut.start()

        await waitUntil { sut.isFinished }
        XCTAssertEqual(pool.deletedRecordRequests.first?.id, "sensor-1")
    }

    func testBackgroundProcessScheduleSubmitsNonPowerNonNetworkRequest() {
        let scheduler = BackgroundTaskSchedulerSpy()
        let sut = BackgroundProcessServiceiOS13(
            dataPruningOperationsManager: makeManager(),
            scheduler: scheduler,
            operationQueueFactory: { OperationQueueSpy() }
        )

        sut.schedule()

        XCTAssertEqual(scheduler.submittedRequests.count, 1)
        XCTAssertEqual(scheduler.submittedRequests.first?.identifier, backgroundTaskIdentifier)
        XCTAssertEqual(scheduler.submittedRequests.first?.requiresExternalPower, false)
        XCTAssertEqual(scheduler.submittedRequests.first?.requiresNetworkConnectivity, false)
    }

    func testBackgroundProcessScheduleSwallowsSchedulerSubmitErrors() {
        let scheduler = BackgroundTaskSchedulerSpy()
        scheduler.submitError = TestError()
        let sut = BackgroundProcessServiceiOS13(
            dataPruningOperationsManager: makeManager(),
            scheduler: scheduler,
            operationQueueFactory: { OperationQueueSpy() }
        )

        sut.schedule()

        XCTAssertEqual(scheduler.makeRequestCalls, [backgroundTaskIdentifier])
        XCTAssertEqual(scheduler.submittedRequests.count, 0)
    }

    func testBackgroundProcessCompletesImmediatelyWhenNoOperationsExist() async {
        let scheduler = BackgroundTaskSchedulerSpy()
        let task = BackgroundProcessingTaskSpy()
        let completed = expectation(description: "task completed")
        task.onComplete = { success in
            XCTAssertTrue(success)
            completed.fulfill()
        }
        let sut = BackgroundProcessServiceiOS13(
            dataPruningOperationsManager: makeManager(sensors: []),
            scheduler: scheduler,
            operationQueueFactory: { OperationQueueSpy() }
        )

        sut.register()
        scheduler.launchHandler?(task)

        await fulfillment(of: [completed], timeout: 1)
        XCTAssertEqual(scheduler.submittedRequests.count, 1)
    }

    func testBackgroundProcessMarksFailureWhenPruningOperationsLoadFails() async {
        let scheduler = BackgroundTaskSchedulerSpy()
        let task = BackgroundProcessingTaskSpy()
        let completed = expectation(description: "task completed with failure")
        task.onComplete = { success in
            XCTAssertFalse(success)
            completed.fulfill()
        }
        let sut = BackgroundProcessServiceiOS13(
            dataPruningOperationsManager: makeManager(storageError: .ruuviPersistence(.failedToFindRuuviTag)),
            scheduler: scheduler,
            operationQueueFactory: { OperationQueueSpy() }
        )

        sut.register()
        scheduler.launchHandler?(task)

        await fulfillment(of: [completed], timeout: 1)
    }

    func testBackgroundProcessStartsOperationsSequentiallyAndCompletesOnSuccess() async {
        let scheduler = BackgroundTaskSchedulerSpy()
        let task = BackgroundProcessingTaskSpy()
        let queue = OperationQueueSpy(autoCompleteLastOperation: true)
        let completed = expectation(description: "task completed after queue")
        task.onComplete = { success in
            XCTAssertTrue(success)
            completed.fulfill()
        }
        let sut = BackgroundProcessServiceiOS13(
            dataPruningOperationsManager: makeManager(sensors: [makeSensor(id: "sensor-1").any]),
            scheduler: scheduler,
            operationQueueFactory: { queue }
        )

        sut.register()
        scheduler.launchHandler?(task)

        await fulfillment(of: [completed], timeout: 1)
        XCTAssertEqual(queue.maxConcurrentOperationCount, 1)
        XCTAssertEqual(queue.addedOperations.count, 1)
        XCTAssertNotNil(task.expirationHandler)
    }

    func testBackgroundProcessCancelsOperationsOnExpirationAndReportsFailure() async {
        let scheduler = BackgroundTaskSchedulerSpy()
        let task = BackgroundProcessingTaskSpy()
        let queue = OperationQueueSpy(autoCompleteLastOperation: false)
        let operationsQueued = expectation(description: "operations queued")
        queue.onAddOperations = {
            operationsQueued.fulfill()
        }
        let completed = expectation(description: "task completed after cancellation")
        task.onComplete = { success in
            XCTAssertFalse(success)
            completed.fulfill()
        }
        let sut = BackgroundProcessServiceiOS13(
            dataPruningOperationsManager: makeManager(sensors: [makeSensor(id: "sensor-1").any]),
            scheduler: scheduler,
            operationQueueFactory: { queue }
        )

        sut.register()
        scheduler.launchHandler?(task)
        await fulfillment(of: [operationsQueued], timeout: 1)
        task.expirationHandler?()
        queue.addedOperations.last?.completionBlock?()

        await fulfillment(of: [completed], timeout: 1)
        XCTAssertTrue(queue.cancelAllOperationsCalls > 0)
        XCTAssertTrue(queue.addedOperations.last?.isCancelled == true)
    }

    func testBackgroundTaskRequestAdapterPersistsFlagsOnWrappedRequest() {
        let sut = BGProcessingTaskRequestAdapter(identifier: backgroundTaskIdentifier)

        sut.requiresExternalPower = true
        sut.requiresNetworkConnectivity = true

        XCTAssertTrue(sut.requiresExternalPower)
        XCTAssertTrue(sut.requiresNetworkConnectivity)
        XCTAssertEqual(sut.request.identifier, backgroundTaskIdentifier)
        XCTAssertTrue(sut.request.requiresExternalPower)
        XCTAssertTrue(sut.request.requiresNetworkConnectivity)
    }

    func testBackgroundTaskAdapterForwardsExpirationAndCompletion() {
        let task = PlatformBackgroundProcessingTaskSpy()
        let sut = BGProcessingTaskAdapter(task: task)
        let expiration = expectation(description: "expiration forwarded")

        sut.expirationHandler = {
            expiration.fulfill()
        }

        XCTAssertNotNil(sut.expirationHandler)
        task.expirationHandler?()
        sut.setTaskCompleted(success: true)

        wait(for: [expiration], timeout: 1)
        XCTAssertEqual(task.completedValues, [true])
    }

    func testSystemBackgroundTaskSchedulerRegistersLaunchHandlerAndSubmitsSupportedRequests() throws {
        let platformScheduler = PlatformBackgroundTaskSchedulerSpy()
        let sut = SystemBackgroundTaskScheduler(scheduler: platformScheduler)
        var launchedTask: BackgroundProcessingTasking?

        XCTAssertTrue(sut.register(identifier: backgroundTaskIdentifier) { task in
            launchedTask = task
        })

        let platformTask = PlatformBackgroundProcessingTaskSpy()
        platformScheduler.launchHandler?(platformTask)

        let receivedTask = try XCTUnwrap(launchedTask)
        let expiration = expectation(description: "wrapped task expiration")
        receivedTask.expirationHandler = {
            expiration.fulfill()
        }

        XCTAssertNotNil(receivedTask.expirationHandler)
        platformTask.expirationHandler?()
        receivedTask.setTaskCompleted(success: false)

        let request = sut.makeRequest(identifier: backgroundTaskIdentifier)
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = true
        try sut.submit(request)

        wait(for: [expiration], timeout: 1)
        XCTAssertEqual(platformScheduler.registerIdentifiers, [backgroundTaskIdentifier])
        XCTAssertEqual(platformTask.completedValues, [false])
        XCTAssertEqual(platformScheduler.submittedRequests.count, 1)
        XCTAssertEqual(platformScheduler.submittedRequests.first?.identifier, backgroundTaskIdentifier)
        XCTAssertTrue(platformScheduler.submittedRequests.first?.requiresExternalPower == true)
        XCTAssertTrue(platformScheduler.submittedRequests.first?.requiresNetworkConnectivity == true)
    }

    func testSystemBackgroundTaskSchedulerIgnoresUnsupportedRequests() {
        let platformScheduler = PlatformBackgroundTaskSchedulerSpy()
        let sut = SystemBackgroundTaskScheduler(scheduler: platformScheduler)

        XCTAssertNoThrow(
            try sut.submit(BackgroundProcessingRequestSpy(identifier: backgroundTaskIdentifier))
        )
        XCTAssertTrue(sut.makeRequest(identifier: backgroundTaskIdentifier) is BGProcessingTaskRequestAdapter)
        XCTAssertEqual(platformScheduler.submittedRequests.count, 0)
    }

    func testLivePlatformBackgroundTaskSchedulerUsesInjectedClosures() throws {
        let task = PlatformBackgroundProcessingTaskSpy()
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        var registeredIdentifiers: [String] = []
        var submittedIdentifiers: [String] = []
        let sut = LivePlatformBackgroundTaskScheduler(
            registerClosure: { identifier, launchHandler in
                registeredIdentifiers.append(identifier)
                launchHandler(task)
                return true
            },
            submitClosure: { request in
                submittedIdentifiers.append(request.identifier)
            }
        )
        var launchedTask: PlatformBackgroundProcessingTasking?

        XCTAssertTrue(sut.register(identifier: backgroundTaskIdentifier) { receivedTask in
            launchedTask = receivedTask
        })
        try sut.submit(request)

        XCTAssertEqual(registeredIdentifiers, [backgroundTaskIdentifier])
        XCTAssertEqual(submittedIdentifiers, [backgroundTaskIdentifier])
        XCTAssertTrue((launchedTask as AnyObject?) === task)
    }

    func testOperationQueueAdapterExecutesOperationsAndCancelsQueuedWork() async {
        let sut = OperationQueueAdapter()
        let started = expectation(description: "first operation started")
        let firstCanFinish = DispatchSemaphore(value: 0)
        let first = BlockOperation {
            started.fulfill()
            _ = firstCanFinish.wait(timeout: .now() + 1)
        }
        let second = BlockOperation {
            XCTFail("Expected queued operation to be cancelled")
        }
        second.addDependency(first)

        sut.maxConcurrentOperationCount = 1
        sut.addOperations([first, second], waitUntilFinished: false)
        await fulfillment(of: [started], timeout: 1)
        XCTAssertEqual(sut.maxConcurrentOperationCount, 1)

        sut.cancelAllOperations()
        firstCanFinish.signal()

        await waitUntil {
            first.isFinished && second.isFinished
        }
        XCTAssertTrue(first.isCancelled)
        XCTAssertTrue(second.isCancelled)
    }

    func testBackgroundProcessDefaultInitializerCreatesService() {
        let sut = BackgroundProcessServiceiOS13(dataPruningOperationsManager: makeManager())
        XCTAssertNotNil(sut)
    }

    func testBackgroundProcessDefaultOperationQueueFactoryCreatesAdapter() {
        XCTAssertTrue(BackgroundProcessServiceiOS13.makeOperationQueue() is OperationQueueAdapter)
    }

    func testFactoryCreatesCloudSyncWorker() {
        let daemon = RuuviDaemonFactoryImpl().createCloudSync(
            localSettings: SettingsStub(),
            localSyncState: LocalSyncStateStub(),
            cloudSyncService: CloudSyncServiceSpy()
        )

        XCTAssertTrue(daemon is RuuviDaemonCloudSyncWorker)
    }

    func testHeartbeatDaemonPublicInitializerCreatesAdapterBackedDaemon() {
        let alertService = RuuviServiceAlertImpl(
            cloud: NoOpCloud(),
            localIDs: RuuviLocalIDsProtocolStub(),
            ruuviLocalSettings: SettingsStub()
        )
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: .shared,
            localNotificationsManager: NotificationLocalProtocolStub(),
            connectionPersistence: LocalConnectionsProtocolStub(),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: HeartbeatReactorSpy(),
            alertService: alertService,
            alertHandler: NotifierProtocolStub(),
            settings: SettingsStub(),
            titles: HeartbeatTitlesStub()
        )

        XCTAssertNotNil(sut)
    }

    func testHeartbeatDaemonStartsObservingAndConnectsPersistedTags() async {
        let background = HeartbeatBackgroundSpy()
        let notifications = HeartbeatNotificationsSpy()
        let connections = HeartbeatConnectionsSpy(keepConnectionUUIDs: ["luid-1".luid.any])
        let reactor = HeartbeatReactorSpy()
        let alertService = HeartbeatAlertSpy()
        let notifier = HeartbeatNotifierSpy()
        let settings = SettingsStub()
        settings.saveHeartbeats = true
        settings.appIsOnForeground = false
        settings.cloudModeEnabled = false
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: notifications,
            connectionPersistence: connections,
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: alertService,
            alertHandler: notifier,
            settings: settings,
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }

        reactor.emitSensors(
            .initial([makeHeartbeatSensor(
                id: "sensor-1",
                luid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF",
                serviceUUID: "service-1"
            ).any])
        )

        await waitUntil {
            background.connectCalls == ["luid-1"]
                && background.observeCalls == ["service-1"]
                && reactor.sensorSettingsObservers.keys.sorted() == ["AA:BB:CC:DD:EE:FF"]
        }
    }

    func testHeartbeatDaemonConnectionCallbacksShowNotificationsWhenAlertIsEnabled() async {
        let background = HeartbeatBackgroundSpy()
        let notifications = HeartbeatNotificationsSpy()
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: notifications,
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any]
            ),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(isConnectionAlertOn: true),
            alertHandler: HeartbeatNotifierSpy(),
            settings: settings,
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(
            .initial([makeHeartbeatSensor(
                id: "sensor-1",
                luid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF",
                serviceUUID: "service-1"
            ).any])
        )
        await waitUntil { background.connectRegistrations["luid-1"] != nil }

        background.emitConnected(uuid: "luid-1", result: .just)
        await waitUntil { notifications.didConnectUUIDs == ["luid-1"] }

        background.emitConnected(uuid: "luid-1", result: .already)
        background.emitConnected(uuid: "luid-1", result: .disconnected)
        await waitUntil { notifications.didDisconnectUUIDs == ["luid-1"] }

        background.emitDisconnected(uuid: "luid-1", result: .just)
        background.emitDisconnected(uuid: "luid-1", result: .already)
        await waitUntil { notifications.didDisconnectUUIDs == ["luid-1", "luid-1"] }
    }

    func testHeartbeatDaemonHeartbeatCallbackProcessesMatchingTagThroughNotifier() async {
        let background = HeartbeatBackgroundSpy()
        let reactor = HeartbeatReactorSpy()
        let notifier = HeartbeatNotifierSpy()
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any]
            ),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: notifier,
            settings: SettingsStub(),
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(
            .initial([makeHeartbeatSensor(
                id: "sensor-1",
                luid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF",
                serviceUUID: "service-1"
            ).any])
        )
        await waitUntil { background.connectRegistrations["luid-1"] != nil }

        background.emitHeartbeat(
            uuid: "luid-1",
            device: makeHeartbeatDevice(uuid: "luid-1")
        )

        await waitUntil { notifier.processedRecords.count == 1 }
        XCTAssertEqual(notifier.processedRecords.first?.luid?.value, "luid-1")
        XCTAssertEqual(notifier.processedRecords.first?.source, .heartbeat)
    }

    func testHeartbeatDaemonPostsFailureNotificationForConnectionCallbackErrors() async {
        let background = HeartbeatBackgroundSpy()
        let reactor = HeartbeatReactorSpy()
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any]
            ),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: HeartbeatNotifierSpy(),
            settings: SettingsStub(),
            titles: HeartbeatTitlesStub()
        )
        let posted = expectation(description: "heartbeat btkit errors posted")
        posted.expectedFulfillmentCount = 2
        let observer = NotificationCenter.default.addObserver(
            forName: .RuuviTagHeartbeatDaemonDidFail,
            object: nil,
            queue: .main
        ) { notification in
            let error = notification.userInfo?[RuuviTagHeartbeatDaemonDidFailKey.error]
                as? RuuviDaemonError
            if case .btkit = error {
                posted.fulfill()
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(
            .initial([makeHeartbeatSensor(
                id: "sensor-1",
                luid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF",
                serviceUUID: "service-1"
            ).any])
        )
        await waitUntil { background.connectRegistrations["luid-1"] != nil }

        background.emitConnected(uuid: "luid-1", result: .failure(.logic(.notConnected)))
        background.emitDisconnected(uuid: "luid-1", result: .failure(.logic(.connectionTimedOut)))

        await fulfillment(of: [posted], timeout: 1)
    }

    func testHeartbeatDaemonHandlesUpdateInsertAndDeleteReactorChanges() async {
        let background = HeartbeatBackgroundSpy()
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.saveHeartbeats = true
        settings.cloudModeEnabled = false
        settings.appIsOnForeground = false
        let initialSensor = makeHeartbeatSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            serviceUUID: "service-1"
        ).any
        let insertedSensor = makeHeartbeatSensor(
            id: "sensor-2",
            luid: "luid-2",
            mac: "11:22:33:44:55:66",
            serviceUUID: "service-2"
        ).any
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any, "luid-2".luid.any]
            ),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: HeartbeatNotifierSpy(),
            settings: settings,
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([initialSensor]))
        await waitUntil {
            background.connectCalls.contains("luid-1")
                && background.observeCalls.contains("service-1")
        }

        reactor.emitSensors(.update(initialSensor))
        await waitUntil { reactor.sensorSettingsObservers.keys.contains("AA:BB:CC:DD:EE:FF") }

        reactor.emitSensors(.insert(insertedSensor))
        await waitUntil {
            background.connectCalls.contains("luid-2")
                && background.observeCalls.contains("service-2")
        }

        reactor.emitSensors(.delete(initialSensor))
        await waitUntil { background.disconnectCalls.contains("luid-1") }
    }

    func testHeartbeatDaemonStopDisconnectsPersistedConnections() async {
        let background = HeartbeatBackgroundSpy()
        let reactor = HeartbeatReactorSpy()
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any]
            ),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: HeartbeatNotifierSpy(),
            settings: SettingsStub(),
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(
            .initial([makeHeartbeatSensor(
                id: "sensor-1",
                luid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF",
                serviceUUID: "service-1"
            ).any])
        )
        await waitUntil { background.connectRegistrations["luid-1"] != nil }

        sut.stop()

        await waitUntil { background.disconnectCalls.contains("luid-1") }
    }

    func testHeartbeatDaemonSavesVersion5HeartbeatsAndResetsThrottleWhenSettingsChange() async {
        let background = HeartbeatBackgroundSpy()
        let pool = PoolSpy()
        let reactor = HeartbeatReactorSpy()
        let notifier = HeartbeatNotifierSpy()
        let settings = SettingsStub()
        settings.saveHeartbeats = true
        settings.saveHeartbeatsIntervalMinutes = 10
        let sensor = makeHeartbeatSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            serviceUUID: "service-1"
        )
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any]
            ),
            ruuviPool: pool,
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: notifier,
            settings: settings,
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor.any]))
        await waitUntil { background.connectRegistrations["luid-1"] != nil }

        let initialSettings = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            temperatureOffset: 1,
            humidityOffset: nil,
            pressureOffset: nil
        )
        reactor.emitSensorSettings(for: sensor.id, .initial([initialSettings]))

        background.emitHeartbeat(uuid: "luid-1", device: makeHeartbeatDevice(uuid: "luid-1"))

        await waitUntil {
            pool.createdSensorRecords.count == 1
                && pool.createdLastRecords.count == 1
                && notifier.processedRecords.count == 1
        }
        XCTAssertEqual(
            notifier.processedRecords.first?.temperature?.converted(to: .celsius).value ?? 0,
            22.5,
            accuracy: 0.0001
        )

        background.emitHeartbeat(uuid: "luid-1", device: makeHeartbeatDevice(uuid: "luid-1"))
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(pool.createdSensorRecords.count, 1)
        XCTAssertEqual(pool.createdLastRecords.count, 1)
        XCTAssertEqual(notifier.processedRecords.count, 2)

        let updatedSettings = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            temperatureOffset: 2,
            humidityOffset: nil,
            pressureOffset: nil
        )
        reactor.emitSensorSettings(for: sensor.id, .update(updatedSettings))
        try? await Task.sleep(nanoseconds: 50_000_000)

        background.emitHeartbeat(uuid: "luid-1", device: makeHeartbeatDevice(uuid: "luid-1"))

        await waitUntil {
            pool.createdSensorRecords.count == 2
                && pool.createdLastRecords.count == 2
                && notifier.processedRecords.count == 3
        }
        XCTAssertEqual(
            notifier.processedRecords.last?.temperature?.converted(to: .celsius).value ?? 0,
            23.5,
            accuracy: 0.0001
        )

        reactor.emitSensorSettings(for: sensor.id, .delete(updatedSettings))
        background.emitHeartbeat(uuid: "luid-1", device: makeHeartbeatDevice(uuid: "luid-1"))

        await waitUntil { notifier.processedRecords.count == 4 }
        XCTAssertEqual(
            notifier.processedRecords.last?.temperature?.converted(to: .celsius).value ?? 0,
            21.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(pool.createdSensorRecords.count, 2)
        XCTAssertEqual(pool.createdLastRecords.count, 2)
    }

    func testHeartbeatDaemonStoresOnlyLastRecordForVersion6Heartbeat() async {
        let background = HeartbeatBackgroundSpy()
        let pool = PoolSpy()
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.saveHeartbeats = true
        settings.saveHeartbeatsIntervalMinutes = 10
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any]
            ),
            ruuviPool: pool,
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: HeartbeatNotifierSpy(),
            settings: settings,
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(
            .initial([makeHeartbeatSensor(
                id: "sensor-1",
                luid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF",
                serviceUUID: "service-1"
            ).any])
        )
        await waitUntil { background.connectRegistrations["luid-1"] != nil }

        background.emitHeartbeat(
            uuid: "luid-1",
            device: makeHeartbeatDevice(uuid: "luid-1", version: 0x06)
        )

        await waitUntil { pool.createdLastRecords.count == 1 }
        XCTAssertEqual(pool.createdSensorRecords.count, 0)
    }

    func testHeartbeatDaemonInsertSensorSettingsAppliesOffsetToNotifierRecord() async {
        let background = HeartbeatBackgroundSpy()
        let reactor = HeartbeatReactorSpy()
        let notifier = HeartbeatNotifierSpy()
        let sensor = makeHeartbeatSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            serviceUUID: "service-1"
        )
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any]
            ),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: notifier,
            settings: SettingsStub(),
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor.any]))
        await waitUntil { background.connectRegistrations["luid-1"] != nil }

        let insertedSettings = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            temperatureOffset: 3,
            humidityOffset: nil,
            pressureOffset: nil
        )
        reactor.emitSensorSettings(for: sensor.id, .insert(insertedSettings))

        background.emitHeartbeat(uuid: "luid-1", device: makeHeartbeatDevice(uuid: "luid-1"))

        await waitUntil { notifier.processedRecords.count == 1 }
        XCTAssertEqual(
            notifier.processedRecords.first?.temperature?.converted(to: .celsius).value ?? 0,
            24.5,
            accuracy: 0.0001
        )
    }

    func testHeartbeatDaemonRespondsToConnectionAndRestartNotifications() async {
        let background = HeartbeatBackgroundSpy()
        let reactor = HeartbeatReactorSpy()
        let notifier = HeartbeatNotifierSpy()
        let settings = SettingsStub()
        settings.saveHeartbeats = true
        settings.cloudModeEnabled = false
        settings.appIsOnForeground = false
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any]
            ),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: notifier,
            settings: settings,
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(
            .initial([makeHeartbeatSensor(
                id: "sensor-1",
                luid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF",
                serviceUUID: "service-1"
            ).any])
        )
        await waitUntil {
            background.connectCalls == ["luid-1"]
                && background.observeCalls == ["service-1"]
        }

        await MainActor.run {
            NotificationCenter.default.post(
                name: .ConnectionPersistenceDidStartToKeepConnection,
                object: nil,
                userInfo: [CPDidStartToKeepConnectionKey.uuid: "luid-1"]
            )
        }
        await waitUntil { background.connectCalls.count >= 2 }

        await MainActor.run {
            NotificationCenter.default.post(
                name: .ConnectionPersistenceDidStopToKeepConnection,
                object: nil,
                userInfo: [CPDidStopToKeepConnectionKey.uuid: "luid-1"]
            )
        }
        await waitUntil { background.disconnectCalls.contains("luid-1") }

        let initialObserveCount = background.observeCalls.count
        await MainActor.run {
            NotificationCenter.default.post(name: .RuuviTagHeartBeatDaemonShouldRestart, object: nil)
        }
        await waitUntil { background.observeCalls.count > initialObserveCount }

        let afterRestartObserveCount = background.observeCalls.count
        await MainActor.run {
            NotificationCenter.default.post(name: .CloudModeDidChange, object: nil)
        }
        await waitUntil { background.observeCalls.count > afterRestartObserveCount }

        let afterCloudModeObserveCount = background.observeCalls.count
        await MainActor.run {
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        await waitUntil { background.observeCalls.count > afterCloudModeObserveCount }

        let afterActiveObserveCount = background.observeCalls.count
        await MainActor.run {
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
        await waitUntil { background.observeCalls.count > afterActiveObserveCount }

        background.emitObserved(
            uuid: "service-1",
            device: makeC5Device(uuid: "luid-1", serviceUUID: "service-1")
        )
        await waitUntil {
            notifier.processedRecords.contains(where: { $0.source == .bgAdvertisement })
        }
    }

    func testHeartbeatDaemonSkipsBackgroundObservationWhenTagIsAlreadyConnected() async {
        let background = HeartbeatBackgroundSpy()
        background.isConnectedValues["luid-1"] = true
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.saveHeartbeats = true
        settings.cloudModeEnabled = false
        settings.appIsOnForeground = false
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(keepConnectionUUIDs: []),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: HeartbeatNotifierSpy(),
            settings: settings,
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(
            .initial([
                makeHeartbeatSensor(
                    id: "sensor-1",
                    luid: "luid-1",
                    mac: "AA:BB:CC:DD:EE:FF",
                    serviceUUID: "service-1"
                ).any,
                makeHeartbeatSensorWithoutLuid(
                    id: "sensor-2",
                    mac: "11:22:33:44:55:66",
                    serviceUUID: "service-2"
                ).any,
            ])
        )

        await waitUntil { background.isConnectedCalls == ["luid-1"] }
        XCTAssertTrue(background.observeCalls.isEmpty)
    }

    func testHeartbeatDaemonIgnoresSensorSettingsErrors() async {
        let background = HeartbeatBackgroundSpy()
        let reactor = HeartbeatReactorSpy()
        let sensor = makeHeartbeatSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            serviceUUID: "service-1"
        )
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any]
            ),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: HeartbeatNotifierSpy(),
            settings: SettingsStub(),
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor.any]))
        await waitUntil { reactor.sensorSettingsObservers.keys.contains(sensor.id) }

        reactor.emitSensorSettings(for: sensor.id, .error(.ruuviPersistence(.failedToFindRuuviTag)))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNotNil(reactor.sensorSettingsObservers[sensor.id])
    }

    func testHeartbeatDaemonRestartReadsSensorsFromStorageAndRebuildsObservationState() async {
        let background = HeartbeatBackgroundSpy()
        let reactor = HeartbeatReactorSpy()
        let storage = StorageSpy()
        let settings = SettingsStub()
        settings.saveHeartbeats = true
        settings.cloudModeEnabled = false
        settings.appIsOnForeground = false
        let storedSensor = makeHeartbeatSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            serviceUUID: "service-1"
        ).any
        storage.sensors = [storedSensor]
        storage.sensorSettingsBySensorId[storedSensor.id] = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            temperatureOffset: 1,
            humidityOffset: nil,
            pressureOffset: nil
        )
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any]
            ),
            ruuviPool: PoolSpy(),
            ruuviStorage: storage,
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: HeartbeatNotifierSpy(),
            settings: settings,
            titles: HeartbeatTitlesStub()
        )

        sut.restart()

        await waitUntil {
            background.connectCalls.contains("luid-1")
                && background.observeCalls.contains("service-1")
                && reactor.sensorSettingsObservers.keys.contains("AA:BB:CC:DD:EE:FF")
        }
    }

    func testAdvertisementDaemonObservesEligibleTagsAndPersistsForegroundSequenceChanges() async {
        let foreground = AdvertisementForegroundSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.appIsOnForeground = true
        settings.cloudModeEnabled = false
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        storage.latestRecordBySensorId[sensor.id] = makeAdvertisementTag(
            uuid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF"
        ).with(source: .advertisement)
        storage.sensorSettingsBySensorId[sensor.id] = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            temperatureOffset: 1,
            humidityOffset: nil,
            pressureOffset: nil
        )
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: pool,
            ruuviStorage: storage,
            ruuviReactor: reactor,
            foreground: foreground,
            settings: settings
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))

        await waitUntil {
            foreground.observeCalls == ["luid-1"]
                && reactor.sensorSettingsObservers.keys.sorted() == ["AA:BB:CC:DD:EE:FF"]
        }

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(tag: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"))
        )

        await waitUntil {
            pool.createdSensorRecords.count == 1 && pool.updatedLastRecords.count == 1
        }

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(tag: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"))
        )
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(pool.createdSensorRecords.count, 1)
        XCTAssertEqual(pool.updatedLastRecords.count, 1)

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(tag: makeAdvertisementTag(
                uuid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF",
                sequence: nil
            ))
        )

        await waitUntil { pool.createdSensorRecords.count == 2 }
    }

    func testAdvertisementDaemonSkipsCloudSensorsInCloudModeAndThrottlesBackgroundLatestOnlyPersistence() async {
        let foreground = AdvertisementForegroundSpy()
        let pool = PoolSpy()
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.appIsOnForeground = false
        settings.cloudModeEnabled = true
        settings.advertisementDaemonIntervalMinutes = 1
        let localSensor = makeSensor(
            id: "local",
            luid: "local-luid",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let cloudSensor = makeSensor(
            id: "cloud",
            luid: "cloud-luid",
            mac: "11:22:33:44:55:66",
            isCloudSensor: true
        ).any
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: pool,
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            settings: settings
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([localSensor, cloudSensor]))

        await waitUntil { foreground.observeCalls == ["local-luid"] }

        let v6Tag = makeAdvertisementTag(
            uuid: "local-luid",
            mac: "AA:BB:CC:DD:EE:FF",
            version: 0x06
        )
        foreground.emitObserved(uuid: "local-luid", device: makeDevice(tag: v6Tag))
        await waitUntil { pool.createdLastRecords.count == 1 }

        foreground.emitObserved(uuid: "local-luid", device: makeDevice(tag: v6Tag))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(pool.createdLastRecords.count, 1)
        XCTAssertEqual(pool.createdSensorRecords.count, 0)
    }

    func testAdvertisementDaemonSkipsLatestRecordMutationWhenLatestReadFails() async {
        let foreground = AdvertisementForegroundSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.appIsOnForeground = true
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        storage.readLatestErrorsBySensorId[sensor.id] = TestError()
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: pool,
            ruuviStorage: storage,
            ruuviReactor: reactor,
            foreground: foreground,
            settings: settings
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))
        await waitUntil { foreground.observeCalls == ["luid-1"] }

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(tag: makeAdvertisementTag(
                uuid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF",
                version: 0x06
            ))
        )

        await waitUntil { storage.readLatestCalls == [sensor.id] }
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(pool.createdLastRecords.isEmpty)
        XCTAssertTrue(pool.updatedLastRecords.isEmpty)
        XCTAssertTrue(pool.createdSensorRecords.isEmpty)
    }

    func testAdvertisementDaemonRemovesMissingSensorAfterHistoryCreateFailure() async {
        let foreground = AdvertisementForegroundSpy()
        let pool = PoolSpy()
        pool.createRecordError = RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.appIsOnForeground = true
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: pool,
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            settings: settings
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))
        await waitUntil { foreground.observeCalls == ["luid-1"] }

        let device = makeDevice(tag: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"))
        foreground.emitObserved(uuid: "luid-1", device: device)
        await waitUntil { foreground.invalidatedObserveUUIDs.contains("luid-1") }
        let createCallsAfterFailure = pool.createdSensorRecords.count

        foreground.emitObserved(uuid: "luid-1", device: device)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(pool.createdSensorRecords.count, createCallsAfterFailure)
    }

    func testAdvertisementDaemonPostsPoolFailureForRecoverableAndGenericCreateErrors() async {
        let foreground = AdvertisementForegroundSpy()
        let pool = PoolSpy()
        pool.createRecordError = RuuviPoolError.ruuviPersistence(.grdb(TestError()))
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.appIsOnForeground = true
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: pool,
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            settings: settings
        )
        let posted = expectation(description: "advertisement create errors posted")
        posted.expectedFulfillmentCount = 2
        let observer = NotificationCenter.default.addObserver(
            forName: .RuuviTagAdvertisementDaemonDidFail,
            object: nil,
            queue: .main
        ) { notification in
            let error = notification.userInfo?[RuuviTagAdvertisementDaemonDidFailKey.error]
                as? RuuviDaemonError
            if case .ruuviPool = error {
                posted.fulfill()
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))
        await waitUntil { foreground.observeCalls == ["luid-1"] }

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(tag: makeAdvertisementTag(
                uuid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF",
                sequence: 10
            ))
        )
        await waitUntil { pool.createdSensorRecords.count == 1 }

        pool.createRecordError = TestError()
        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(tag: makeAdvertisementTag(
                uuid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF",
                sequence: 11
            ))
        )

        await fulfillment(of: [posted], timeout: 1)
    }

    func testAdvertisementDaemonUpdatesSensorSettingsFromReactorChanges() async {
        let foreground = AdvertisementForegroundSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.appIsOnForeground = true
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        storage.latestRecordBySensorId[sensor.id] = nil
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: pool,
            ruuviStorage: storage,
            ruuviReactor: reactor,
            foreground: foreground,
            settings: settings
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))
        await waitUntil {
            foreground.observeCalls == ["luid-1"]
                && reactor.sensorSettingsObservers.keys.sorted() == ["AA:BB:CC:DD:EE:FF"]
        }

        reactor.emitSensorSettings(
            for: sensor.id,
            .insert(
                SensorSettingsStruct(
                    luid: "luid-1".luid,
                    macId: "AA:BB:CC:DD:EE:FF".mac,
                    temperatureOffset: 2,
                    humidityOffset: nil,
                    pressureOffset: nil
                )
            )
        )

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(
                tag: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF")
            )
        )

        await waitUntil { pool.createdLastRecords.count == 1 }
        XCTAssertEqual(pool.createdSensorRecords.count, 1)

        reactor.emitSensorSettings(
            for: sensor.id,
            .delete(
                SensorSettingsStruct(
                    luid: "luid-1".luid,
                    macId: "AA:BB:CC:DD:EE:FF".mac,
                    temperatureOffset: 2,
                    humidityOffset: nil,
                    pressureOffset: nil
                )
            )
        )

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(
                tag: makeAdvertisementTag(
                    uuid: "luid-1",
                    mac: "AA:BB:CC:DD:EE:FF",
                    sequence: 2
                )
            )
        )

        await waitUntil { pool.createdSensorRecords.count == 2 }
        XCTAssertEqual(pool.createdLastRecords.count, 2)
    }

    func testAdvertisementDaemonHandlesInitialUpdateAndErrorSensorSettingsChanges() async {
        let foreground = AdvertisementForegroundSpy()
        let pool = PoolSpy()
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.appIsOnForeground = true
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: pool,
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            settings: settings
        )
        let posted = expectation(description: "advertisement settings error posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .RuuviTagAdvertisementDaemonDidFail,
            object: nil,
            queue: .main
        ) { notification in
            let error = notification.userInfo?[RuuviTagAdvertisementDaemonDidFailKey.error]
                as? RuuviDaemonError
            if case .ruuviReactor = error {
                posted.fulfill()
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))
        await waitUntil {
            foreground.observeCalls == ["luid-1"]
                && reactor.sensorSettingsObservers.keys.sorted() == ["AA:BB:CC:DD:EE:FF"]
        }

        let initialSettings = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            temperatureOffset: 1,
            humidityOffset: nil,
            pressureOffset: nil
        )
        reactor.emitSensorSettings(for: sensor.id, .initial([initialSettings]))
        reactor.emitSensorSettings(
            for: sensor.id,
            .update(
                SensorSettingsStruct(
                    luid: "luid-1".luid,
                    macId: "AA:BB:CC:DD:EE:FF".mac,
                    temperatureOffset: 2,
                    humidityOffset: nil,
                    pressureOffset: nil
                )
            )
        )
        reactor.emitSensorSettings(for: sensor.id, .error(.ruuviPersistence(.failedToFindRuuviTag)))

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(
                tag: makeAdvertisementTag(
                    uuid: "luid-1",
                    mac: "AA:BB:CC:DD:EE:FF",
                    sequence: 11
                )
            )
        )

        await fulfillment(of: [posted], timeout: 1)
        await waitUntil {
            pool.createdSensorRecords.count == 1
                && pool.createdLastRecords.count == 1
        }
        XCTAssertEqual(pool.createdLastRecords.count, 1)
    }

    func testAdvertisementDaemonPostsFailureNotificationForReactorErrors() async {
        let foreground = AdvertisementForegroundSpy()
        let reactor = HeartbeatReactorSpy()
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            settings: SettingsStub()
        )
        let posted = expectation(description: "advertisement daemon error posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .RuuviTagAdvertisementDaemonDidFail,
            object: nil,
            queue: .main
        ) { notification in
            let error = notification.userInfo?[RuuviTagAdvertisementDaemonDidFailKey.error]
                as? RuuviDaemonError
            if case .ruuviReactor = error {
                posted.fulfill()
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.error(.ruuviPersistence(.failedToFindRuuviTag)))

        await fulfillment(of: [posted], timeout: 1)
    }

    func testAdvertisementDaemonStopAndRestartInvalidateAndReloadObservers() async {
        let foreground = AdvertisementForegroundSpy()
        let storage = StorageSpy()
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        let initialSensor = makeSensor(
            id: "initial",
            luid: "initial-luid",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        storage.sensors = [
            makeSensor(
                id: "restarted",
                luid: "restarted-luid",
                mac: "11:22:33:44:55:66"
            ).any,
        ]
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviStorage: storage,
            ruuviReactor: reactor,
            foreground: foreground,
            settings: settings
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([initialSensor]))
        await waitUntil {
            foreground.observeCalls.contains("initial-luid")
                && reactor.sensorSettingsObservers.keys.contains("AA:BB:CC:DD:EE:FF")
        }

        sut.stop()
        await waitUntil {
            foreground.invalidatedObserveUUIDs.contains("initial-luid")
                && reactor.sensorSettingsObservers.isEmpty
        }

        sut.restart()
        await waitUntil {
            foreground.observeCalls.contains("restarted-luid")
                && reactor.sensorSettingsObservers.keys.contains("11:22:33:44:55:66")
        }
    }

    func testAdvertisementDaemonHandlesSensorUpdateInsertAndDeleteChanges() async {
        let foreground = AdvertisementForegroundSpy()
        let reactor = HeartbeatReactorSpy()
        let initial = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let updated = makeSensor(
            id: "sensor-1",
            luid: "luid-2",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let inserted = makeSensor(
            id: "sensor-2",
            luid: "luid-3",
            mac: "11:22:33:44:55:66"
        ).any
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            settings: SettingsStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([initial]))
        await waitUntil { foreground.observeCalls.contains("luid-1") }

        reactor.emitSensors(.update(updated))
        await waitUntil {
            foreground.invalidatedObserveUUIDs.contains("luid-1")
                && foreground.observeCalls.contains("luid-2")
        }

        reactor.emitSensors(.insert(inserted))
        await waitUntil { foreground.observeCalls.contains("luid-3") }

        reactor.emitSensors(.delete(updated))
        await waitUntil { foreground.invalidatedObserveUUIDs.contains("luid-2") }
    }

    func testAdvertisementDaemonRespondsToSettingsCloudModeAndRestartNotifications() async {
        let foreground = AdvertisementForegroundSpy()
        let reactor = HeartbeatReactorSpy()
        let storage = StorageSpy()
        let settings = SettingsStub()
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            isCloudSensor: true
        ).any
        let restarted = makeSensor(
            id: "sensor-2",
            luid: "restart-luid",
            mac: "11:22:33:44:55:66",
            isCloudSensor: false
        ).any
        storage.sensors = [restarted]
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviStorage: storage,
            ruuviReactor: reactor,
            foreground: foreground,
            settings: settings
        )

        settings.isAdvertisementDaemonOn = true
        await MainActor.run {
            NotificationCenter.default.post(name: .isAdvertisementDaemonOnDidChange, object: nil)
        }
        await waitUntil { reactor.sensorObserver != nil }

        reactor.emitSensors(.initial([sensor]))
        await waitUntil { foreground.observeCalls.contains("luid-1") }

        settings.isAdvertisementDaemonOn = false
        await MainActor.run {
            NotificationCenter.default.post(name: .isAdvertisementDaemonOnDidChange, object: nil)
        }
        await waitUntil { foreground.invalidatedObserveUUIDs.contains("luid-1") }

        settings.cloudModeEnabled = true
        await MainActor.run {
            NotificationCenter.default.post(name: .CloudModeDidChange, object: nil)
        }
        XCTAssertFalse(foreground.observeRegistrations.keys.contains("luid-1"))

        await MainActor.run {
            NotificationCenter.default.post(name: .RuuviTagAdvertisementDaemonShouldRestart, object: nil)
        }
        await waitUntil { foreground.observeCalls.contains("restart-luid") }

        sut.stop()
    }

    func testAdvertisementDaemonPublicInitializerCreatesAdapterBackedDaemon() {
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: HeartbeatReactorSpy(),
            foreground: .shared,
            settings: SettingsStub()
        )

        XCTAssertNotNil(sut)
    }

    func testPropertiesDaemonPublicInitializerCreatesAdapterBackedDaemon() {
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviReactor: HeartbeatReactorSpy(),
            foreground: .shared,
            idPersistence: RuuviLocalIDsProtocolStub(),
            sqiltePersistence: PersistenceUnusedStub()
        )

        XCTAssertNotNil(sut)
    }

    func testAdvertisementDaemonDeinitInvalidatesObservationAndSettingsTokens() async {
        let foreground = AdvertisementForegroundSpy()
        let reactor = HeartbeatReactorSpy()
        var sut: RuuviTagAdvertisementDaemonBTKit? = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            settings: SettingsStub()
        )

        sut?.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([
            makeSensor(
                id: "sensor-1",
                luid: "luid-1",
                mac: "AA:BB:CC:DD:EE:FF"
            ).any,
        ]))
        await waitUntil {
            foreground.observeCalls == ["luid-1"]
                && reactor.sensorSettingsObservers.keys.sorted() == ["AA:BB:CC:DD:EE:FF"]
        }

        sut = nil

        await waitUntil {
            foreground.invalidatedObserveUUIDs == ["luid-1"]
                && reactor.sensorObserver == nil
                && reactor.sensorSettingsObservers.isEmpty
        }
    }

    func testAdvertisementDaemonContinuesWhenInitialSensorSettingsReadFails() async {
        let foreground = AdvertisementForegroundSpy()
        let storage = StorageSpy()
        let reactor = HeartbeatReactorSpy()
        let sensorWithSettingsFailure = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let sensorWithSettings = makeSensor(
            id: "sensor-2",
            luid: "luid-2",
            mac: "11:22:33:44:55:66"
        ).any
        storage.readSensorSettingsErrorsBySensorId[sensorWithSettingsFailure.id] = TestError()
        storage.sensorSettingsBySensorId[sensorWithSettings.id] = SensorSettingsStruct(
            luid: "luid-2".luid,
            macId: "11:22:33:44:55:66".mac,
            temperatureOffset: 2,
            humidityOffset: nil,
            pressureOffset: nil
        )
        let sut = RuuviTagAdvertisementDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviStorage: storage,
            ruuviReactor: reactor,
            foreground: foreground,
            settings: SettingsStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensorWithSettingsFailure, sensorWithSettings]))

        await waitUntil {
            foreground.observeCalls.sorted() == ["luid-1", "luid-2"]
                && storage.readSensorSettingsCalls.sorted() == [
                    sensorWithSettingsFailure.id,
                    sensorWithSettings.id,
                ].sorted()
        }
    }

    func testPropertiesDaemonObservesKnownSensorAndUpdatesPoolOnVersionChange() async {
        let foreground = PropertiesForegroundSpy()
        let pool = PoolSpy()
        let reactor = HeartbeatReactorSpy()
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            version: 3
        ).any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: pool,
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: LocalIDsSpy(),
            sensorReader: SensorReaderSpy()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))

        await waitUntil { foreground.observeCalls == ["luid-1"] }
        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(
                tag: makeAdvertisementTag(
                    uuid: "luid-1",
                    mac: "AA:BB:CC:DD:EE:FF",
                    version: 5
                )
            )
        )

        await waitUntil { pool.updatedSensors.count == 1 }
        XCTAssertEqual(pool.updatedSensors.first?.version, 5)
    }

    func testPropertiesDaemonScansRemoteCloudSensorAndStoresMappings() async {
        let foreground = PropertiesForegroundSpy()
        let pool = PoolSpy()
        let reactor = HeartbeatReactorSpy()
        let ids = LocalIDsSpy()
        let sensor = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: "1.0.0",
            luid: nil,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            serviceUUID: nil,
            isConnectable: true,
            name: "cloud",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: nil,
            isCloudSensor: true,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: nil
        ).any
        let cloudSensorWithoutMac = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: "1.0.0",
            luid: nil,
            macId: nil,
            serviceUUID: nil,
            isConnectable: true,
            name: "cloud-without-mac",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: nil,
            isCloudSensor: true,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: nil
        ).any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: pool,
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: ids,
            sensorReader: SensorReaderSpy()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor, cloudSensorWithoutMac]))

        await waitUntil { foreground.scanRegistrations.count == 2 }
        foreground.emitScan(
            device: makeHeartbeatDevice(uuid: "unknown")
        )
        foreground.emitScan(
            device: makeDevice(tag: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"))
        )

        await waitUntil {
            pool.updatedSensors.contains(where: {
                $0.luid?.value == "luid-1" && $0.macId?.value == "AA:BB:CC:DD:EE:FF"
            })
                && ids.macByLuid["luid-1"] == "AA:BB:CC:DD:EE:FF"
                && ids.luidByMac["AA:BB:CC:DD:EE:FF"] == "luid-1"
        }

        XCTAssertTrue(pool.updatedSensors.contains(where: { $0.luid?.value == "luid-1" }))
    }

    func testPropertiesDaemonTracksUuidChangesForKnownMacAndUpdatesPersistedSensor() async {
        let foreground = PropertiesForegroundSpy()
        let pool = PoolSpy()
        let reactor = HeartbeatReactorSpy()
        let ids = LocalIDsSpy()
        let reader = SensorReaderSpy()
        reader.sensorById["AA:BB:CC:DD:EE:FF"] = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: "1.0.0",
            luid: nil,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            serviceUUID: nil,
            isConnectable: true,
            name: "sensor-1",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: nil,
            isCloudSensor: false,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: nil
        ).any
        let observedSensor = makeSensor(
            id: "sensor-1",
            luid: "old-luid",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: pool,
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: ids,
            sensorReader: reader
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([observedSensor]))

        await waitUntil { foreground.scanRegistrations.count == 1 }
        foreground.emitScan(
            device: makeDevice(tag: makeAdvertisementTag(uuid: "new-luid", mac: "AA:BB:CC:DD:EE:FF"))
        )

        await waitUntil {
            pool.updatedSensors.count == 1
                && ids.luidByMac["AA:BB:CC:DD:EE:FF"] == "new-luid"
        }

        XCTAssertEqual(pool.updatedSensors.first?.luid?.value, "new-luid")
    }

    func testPropertiesDaemonIgnoresUuidChangeWhenPersistedMappingAlreadyMatches() async {
        let foreground = PropertiesForegroundSpy()
        let pool = PoolSpy()
        let reactor = HeartbeatReactorSpy()
        let ids = LocalIDsSpy()
        ids.luidByMac["AA:BB:CC:DD:EE:FF"] = "same-luid"
        let knownSensor = makeSensor(
            id: "sensor-1",
            luid: "same-luid",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: pool,
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: ids,
            sensorReader: SensorReaderSpy()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([knownSensor]))
        await waitUntil { foreground.scanRegistrations.count == 1 }

        foreground.emitScan(
            device: makeDevice(tag: makeAdvertisementTag(uuid: "same-luid", mac: "AA:BB:CC:DD:EE:FF"))
        )
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(pool.updatedSensors.isEmpty)
        XCTAssertEqual(ids.luidByMac["AA:BB:CC:DD:EE:FF"], "same-luid")
    }

    func testPropertiesDaemonRestartsObservingOnInsertUpdateAndDeleteChanges() async {
        let foreground = PropertiesForegroundSpy()
        let reactor = HeartbeatReactorSpy()
        let initial = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let updated = makeSensor(
            id: "sensor-1",
            luid: "luid-2",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: LocalIDsSpy(),
            sensorReader: SensorReaderSpy()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([]))

        reactor.emitSensors(.insert(initial))
        await waitUntil { foreground.observeCalls.contains("luid-1") }

        reactor.emitSensors(.update(updated))
        await waitUntil {
            foreground.invalidatedObserveUUIDs.contains("luid-1")
                && foreground.observeCalls.contains("luid-2")
        }

        reactor.emitSensors(.delete(updated))
        await waitUntil { foreground.invalidatedObserveUUIDs.contains("luid-2") }
    }

    func testPropertiesDaemonMatchesUpdateAndDeleteByLuidWhenMacIsMissing() async {
        let foreground = PropertiesForegroundSpy()
        let reactor = HeartbeatReactorSpy()
        let initial = makeSensor(
            id: "sensor-1",
            luid: "luid-only"
        ).withoutMac().any
        let updated = makeSensor(
            id: "sensor-1",
            luid: "luid-only",
            version: 6
        ).withoutMac().any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: LocalIDsSpy(),
            sensorReader: SensorReaderSpy()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([initial]))
        await waitUntil { foreground.observeCalls.contains("luid-only") }

        reactor.emitSensors(.update(updated))
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(
            foreground.observeCalls.filter { $0 == "luid-only" }.count,
            2
        )

        reactor.emitSensors(.delete(updated))
        await waitUntil { foreground.invalidatedObserveUUIDs.contains("luid-only") }
    }

    func testPropertiesDaemonRemovesCachedSensorAfterMissingPoolEntry() async {
        let foreground = PropertiesForegroundSpy()
        let pool = PoolSpy()
        pool.updateSensorError = RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        let reactor = HeartbeatReactorSpy()
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            version: 3
        ).any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: pool,
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: LocalIDsSpy(),
            sensorReader: SensorReaderSpy()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))
        await waitUntil { foreground.observeCalls == ["luid-1"] }

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(
                tag: makeAdvertisementTag(
                    uuid: "luid-1",
                    mac: "AA:BB:CC:DD:EE:FF",
                    version: 5
                )
            )
        )

        await waitUntil { foreground.invalidatedObserveUUIDs.contains("luid-1") }
        let updateCallsAfterFailure = pool.updatedSensors.count

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(
                tag: makeAdvertisementTag(
                    uuid: "luid-1",
                    mac: "AA:BB:CC:DD:EE:FF",
                    version: 5
                )
            )
        )
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(pool.updatedSensors.count, updateCallsAfterFailure)
    }

    func testPropertiesDaemonPostsFailureNotificationForNonRecoverablePoolErrors() async {
        let foreground = PropertiesForegroundSpy()
        let pool = PoolSpy()
        pool.updateSensorError = RuuviPoolError.ruuviPersistence(.grdb(TestError()))
        let reactor = HeartbeatReactorSpy()
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            version: 3
        ).any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: pool,
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: LocalIDsSpy(),
            sensorReader: SensorReaderSpy()
        )
        let posted = expectation(description: "properties daemon error posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .RuuviTagPropertiesDaemonDidFail,
            object: nil,
            queue: .main
        ) { notification in
            let error = notification.userInfo?[RuuviTagPropertiesDaemonDidFailKey.error]
                as? RuuviDaemonError
            if case .ruuviPool = error {
                posted.fulfill()
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))
        await waitUntil { foreground.observeCalls == ["luid-1"] }

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(
                tag: makeAdvertisementTag(
                    uuid: "luid-1",
                    mac: "AA:BB:CC:DD:EE:FF",
                    version: 5
                )
            )
        )

        await fulfillment(of: [posted], timeout: 1)
    }

    func testPropertiesDaemonPostsFailureNotificationForUnexpectedPoolErrors() async {
        let foreground = PropertiesForegroundSpy()
        let pool = PoolSpy()
        pool.updateSensorError = TestError()
        let reactor = HeartbeatReactorSpy()
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            version: 3
        ).any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: pool,
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: LocalIDsSpy(),
            sensorReader: SensorReaderSpy()
        )
        let posted = expectation(description: "unexpected properties daemon error posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .RuuviTagPropertiesDaemonDidFail,
            object: nil,
            queue: .main
        ) { notification in
            let error = notification.userInfo?[RuuviTagPropertiesDaemonDidFailKey.error]
                as? RuuviDaemonError
            if case .ruuviPool = error {
                posted.fulfill()
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))
        await waitUntil { foreground.observeCalls == ["luid-1"] }

        foreground.emitObserved(
            uuid: "luid-1",
            device: makeDevice(
                tag: makeAdvertisementTag(
                    uuid: "luid-1",
                    mac: "AA:BB:CC:DD:EE:FF",
                    version: 5
                )
            )
        )

        await fulfillment(of: [posted], timeout: 1)
    }

    func testPropertiesDaemonPostsFailureNotificationForUnexpectedRemoteScanPoolErrors() async {
        let foreground = PropertiesForegroundSpy()
        let pool = PoolSpy()
        pool.updateSensorError = RuuviPoolError.ruuviPersistence(.grdb(TestError()))
        let reactor = HeartbeatReactorSpy()
        let sensor = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: "1.0.0",
            luid: nil,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            serviceUUID: nil,
            isConnectable: true,
            name: "cloud",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: nil,
            isCloudSensor: true,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: nil
        ).any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: pool,
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: LocalIDsSpy(),
            sensorReader: SensorReaderSpy()
        )
        let posted = expectation(description: "unexpected remote scan error posted")
        posted.expectedFulfillmentCount = 2
        let observer = NotificationCenter.default.addObserver(
            forName: .RuuviTagPropertiesDaemonDidFail,
            object: nil,
            queue: .main
        ) { notification in
            let error = notification.userInfo?[RuuviTagPropertiesDaemonDidFailKey.error]
                as? RuuviDaemonError
            if case .ruuviPool = error {
                posted.fulfill()
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))
        await waitUntil { foreground.scanRegistrations.count == 2 }

        foreground.emitScan(
            device: makeDevice(tag: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"))
        )
        await waitUntil { pool.updatedSensors.count >= 1 }

        pool.updateSensorError = TestError()
        foreground.emitScan(
            device: makeDevice(tag: makeAdvertisementTag(uuid: "luid-2", mac: "AA:BB:CC:DD:EE:FF"))
        )

        await fulfillment(of: [posted], timeout: 1)
    }

    func testPropertiesDaemonRemovesRemoteCloudSensorAfterMissingPoolEntryDuringScan() async {
        let foreground = PropertiesForegroundSpy()
        let pool = PoolSpy()
        pool.updateSensorError = RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        let reactor = HeartbeatReactorSpy()
        let sensor = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: "1.0.0",
            luid: nil,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            serviceUUID: nil,
            isConnectable: true,
            name: "cloud",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: nil,
            isCloudSensor: true,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: nil
        ).any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: pool,
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: LocalIDsSpy(),
            sensorReader: SensorReaderSpy()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))
        await waitUntil { foreground.scanRegistrations.count == 2 }

        foreground.emitScan(
            device: makeDevice(tag: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"))
        )

        await waitUntil {
            pool.updatedSensors.contains(where: {
                $0.luid?.value == "luid-1" && $0.macId?.value == "AA:BB:CC:DD:EE:FF"
            })
                && foreground.invalidatedScanCount >= 2
                && foreground.scanRegistrations.count >= 3
        }
    }

    func testPropertiesDaemonStopInvalidatesObserveAndScanTokens() async {
        let foreground = PropertiesForegroundSpy()
        let reactor = HeartbeatReactorSpy()
        let knownSensor = makeSensor(
            id: "known",
            luid: "known-luid",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any
        let remoteCloudSensor = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: "1.0.0",
            luid: nil,
            macId: "11:22:33:44:55:66".mac,
            serviceUUID: nil,
            isConnectable: true,
            name: "remote",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: nil,
            isCloudSensor: true,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: nil
        ).any
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: LocalIDsSpy(),
            sensorReader: SensorReaderSpy()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([knownSensor, remoteCloudSensor]))
        await waitUntil {
            foreground.observeCalls == ["known-luid"]
                && foreground.scanRegistrations.count == 2
        }

        sut.stop()

        await waitUntil {
            foreground.invalidatedObserveUUIDs.contains("known-luid")
                && foreground.invalidatedScanCount == 2
        }
    }

    func testPropertiesDaemonPostsFailureNotificationForReactorErrors() async {
        let foreground = PropertiesForegroundSpy()
        let reactor = HeartbeatReactorSpy()
        let sut = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: LocalIDsSpy(),
            sensorReader: SensorReaderSpy()
        )
        let posted = expectation(description: "properties reactor error posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .RuuviTagPropertiesDaemonDidFail,
            object: nil,
            queue: .main
        ) { notification in
            let error = notification.userInfo?[RuuviTagPropertiesDaemonDidFailKey.error]
                as? RuuviDaemonError
            if case .ruuviReactor = error {
                posted.fulfill()
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.error(.ruuviPersistence(.failedToFindRuuviTag)))

        await fulfillment(of: [posted], timeout: 1)
    }

    func testPropertiesDaemonDeinitInvalidatesObserveAndScanTokens() async {
        let foreground = PropertiesForegroundSpy()
        let reactor = HeartbeatReactorSpy()
        var sut: RuuviTagPropertiesDaemonBTKit? = RuuviTagPropertiesDaemonBTKit(
            ruuviPool: PoolSpy(),
            ruuviReactor: reactor,
            foreground: foreground,
            idPersistence: LocalIDsSpy(),
            sensorReader: SensorReaderSpy()
        )

        sut?.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([
            makeSensor(
                id: "known",
                luid: "known-luid",
                mac: "AA:BB:CC:DD:EE:FF"
            ).any,
            RuuviTagSensorStruct(
                version: 5,
                firmwareVersion: "1.0.0",
                luid: nil,
                macId: "11:22:33:44:55:66".mac,
                serviceUUID: nil,
                isConnectable: true,
                name: "remote",
                isClaimed: true,
                isOwner: true,
                owner: "owner@example.com",
                ownersPlan: nil,
                isCloudSensor: true,
                canShare: false,
                sharedTo: [],
                maxHistoryDays: nil
            ).any,
        ]))
        await waitUntil {
            foreground.observeCalls == ["known-luid"]
                && foreground.scanRegistrations.count == 2
        }

        sut = nil

        await waitUntil {
            foreground.invalidatedObserveUUIDs == ["known-luid"]
                && foreground.invalidatedScanCount == 2
                && reactor.sensorObserver == nil
        }
    }

    func testHeartbeatDaemonPostsFailureNotificationForReactorErrors() async {
        let background = HeartbeatBackgroundSpy()
        let reactor = HeartbeatReactorSpy()
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(keepConnectionUUIDs: []),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: HeartbeatNotifierSpy(),
            settings: SettingsStub(),
            titles: HeartbeatTitlesStub()
        )
        let posted = expectation(description: "heartbeat daemon error posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .RuuviTagHeartbeatDaemonDidFail,
            object: nil,
            queue: .main
        ) { notification in
            let error = notification.userInfo?[RuuviTagHeartbeatDaemonDidFailKey.error]
                as? RuuviDaemonError
            if case .ruuviReactor = error {
                posted.fulfill()
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.error(.ruuviPersistence(.failedToFindRuuviTag)))

        await fulfillment(of: [posted], timeout: 1)
    }

    func testHeartbeatDaemonDeinitInvalidatesObserveConnectDisconnectAndSettingsTokens() async {
        let background = HeartbeatBackgroundSpy()
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.saveHeartbeats = true
        settings.cloudModeEnabled = false
        settings.appIsOnForeground = false
        var sut: RuuviTagHeartbeatDaemonBTKit? = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any]
            ),
            ruuviPool: PoolSpy(),
            ruuviStorage: StorageSpy(),
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: HeartbeatNotifierSpy(),
            settings: settings,
            titles: HeartbeatTitlesStub()
        )
        let sensor = makeHeartbeatSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            serviceUUID: "service-1"
        ).any

        sut?.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensor]))
        await waitUntil {
            background.connectCalls == ["luid-1"]
                && background.observeCalls == ["service-1"]
                && reactor.sensorSettingsObservers.keys.sorted() == ["AA:BB:CC:DD:EE:FF"]
        }

        reactor.emitSensors(.delete(sensor))
        await waitUntil {
            background.invalidatedConnectUUIDs == ["luid-1"]
                && background.disconnectCalls == ["luid-1"]
        }

        sut = nil

        await waitUntil {
            background.invalidatedObserveUUIDs == ["service-1"]
                && background.invalidatedDisconnectUUIDs == ["luid-1"]
                && reactor.sensorObserver == nil
                && reactor.sensorSettingsObservers.isEmpty
        }
    }

    func testHeartbeatDaemonContinuesWhenInitialSensorSettingsReadFails() async {
        let background = HeartbeatBackgroundSpy()
        let storage = StorageSpy()
        let reactor = HeartbeatReactorSpy()
        let settings = SettingsStub()
        settings.saveHeartbeats = true
        settings.cloudModeEnabled = false
        settings.appIsOnForeground = false
        let sensorWithSettingsFailure = makeHeartbeatSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            serviceUUID: "service-1"
        ).any
        let sensorWithSettings = makeHeartbeatSensor(
            id: "sensor-2",
            luid: "luid-2",
            mac: "11:22:33:44:55:66",
            serviceUUID: "service-2"
        ).any
        storage.readSensorSettingsErrorsBySensorId[sensorWithSettingsFailure.id] = TestError()
        storage.sensorSettingsBySensorId[sensorWithSettings.id] = SensorSettingsStruct(
            luid: "luid-2".luid,
            macId: "11:22:33:44:55:66".mac,
            temperatureOffset: 2,
            humidityOffset: nil,
            pressureOffset: nil
        )
        let sut = RuuviTagHeartbeatDaemonBTKit(
            background: background,
            localNotificationsManager: HeartbeatNotificationsSpy(),
            connectionPersistence: HeartbeatConnectionsSpy(
                keepConnectionUUIDs: ["luid-1".luid.any, "luid-2".luid.any]
            ),
            ruuviPool: PoolSpy(),
            ruuviStorage: storage,
            ruuviReactor: reactor,
            alertService: HeartbeatAlertSpy(),
            alertHandler: HeartbeatNotifierSpy(),
            settings: settings,
            titles: HeartbeatTitlesStub()
        )

        sut.start()
        await waitUntil { reactor.sensorObserver != nil }
        reactor.emitSensors(.initial([sensorWithSettingsFailure, sensorWithSettings]))

        await waitUntil {
            background.connectCalls.sorted() == ["luid-1", "luid-2"]
                && background.observeCalls.sorted() == ["service-1", "service-2"]
                && storage.readSensorSettingsCalls.sorted() == [
                    sensorWithSettingsFailure.id,
                    sensorWithSettings.id,
                ].sorted()
        }
    }
}

private final class InspectingWorker: RuuviDaemonWorker {
    var executedOnThread: Thread?
}

private final class CloudSyncServiceSpy: RuuviServiceCloudSync {
    var syncAllRecordsCalls = 0
    var refreshLatestRecordCalls = 0
    var onSyncAllRecords: (() -> Void)?
    var onRefreshLatestRecord: (() -> Void)?

    func syncAll() async throws -> Set<AnyRuuviTagSensor> { [] }
    func sync(sensor: RuuviTagSensor) async throws -> [AnyRuuviTagSensorRecord] { [] }
    func syncAllHistory() async throws -> Bool { true }

    func refreshLatestRecord() async throws -> Bool {
        refreshLatestRecordCalls += 1
        onRefreshLatestRecord?()
        return true
    }

    func syncAllRecords() async throws -> Bool {
        syncAllRecordsCalls += 1
        onSyncAllRecords?()
        return true
    }

    func syncSettings() async throws -> RuuviCloudSettings {
        CloudSettingsStub()
    }

    func executePendingRequests() async throws -> Bool { true }
}

private final class HeartbeatBackgroundSpy: HeartbeatBackgrounding {
    struct ConnectRegistration {
        let connected: (BTConnectResult) -> Void
        let heartbeat: (BTDevice) -> Void
        let disconnected: (BTDisconnectResult) -> Void
    }

    var isConnectedValues: [String: Bool] = [:]
    var isConnectedCalls: [String] = []
    var connectCalls: [String] = []
    var disconnectCalls: [String] = []
    var observeCalls: [String] = []
    var invalidatedConnectUUIDs: [String] = []
    var invalidatedDisconnectUUIDs: [String] = []
    var invalidatedObserveUUIDs: [String] = []
    var connectRegistrations: [String: ConnectRegistration] = [:]
    var observeRegistrations: [String: (BTDevice) -> Void] = [:]

    func isConnected(uuid: String) -> Bool {
        isConnectedCalls.append(uuid)
        return isConnectedValues[uuid] ?? false
    }

    func connect<T: AnyObject>(
        for observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        connected: ((T, BTConnectResult) -> Void)?,
        heartbeat: ((T, BTDevice) -> Void)?,
        disconnected: ((T, BTDisconnectResult) -> Void)?
    ) -> DaemonObservationToken? {
        connectCalls.append(uuid)
        connectRegistrations[uuid] = ConnectRegistration(
            connected: { [weak observer] result in
                guard let observer else { return }
                connected?(observer, result)
            },
            heartbeat: { [weak observer] device in
                guard let observer else { return }
                heartbeat?(observer, device)
            },
            disconnected: { [weak observer] result in
                guard let observer else { return }
                disconnected?(observer, result)
            }
        )
        return DaemonObservationToken { [weak self] in
            self?.invalidatedConnectUUIDs.append(uuid)
            self?.connectRegistrations.removeValue(forKey: uuid)
        }
    }

    func disconnect<T: AnyObject>(
        for observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        result: ((T, BTDisconnectResult) -> Void)?
    ) -> DaemonObservationToken? {
        disconnectCalls.append(uuid)
        return DaemonObservationToken { [weak self, weak observer] in
            self?.invalidatedDisconnectUUIDs.append(uuid)
            guard let observer else { return }
            result?(observer, .just)
        }
    }

    func observe<T: AnyObject>(
        _ observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken {
        observeCalls.append(uuid)
        observeRegistrations[uuid] = { [weak observer] device in
            guard let observer else { return }
            closure(observer, device)
        }
        return DaemonObservationToken { [weak self] in
            self?.invalidatedObserveUUIDs.append(uuid)
            self?.observeRegistrations.removeValue(forKey: uuid)
        }
    }

    func emitConnected(uuid: String, result: BTConnectResult) {
        connectRegistrations[uuid]?.connected(result)
    }

    func emitHeartbeat(uuid: String, device: BTDevice) {
        connectRegistrations[uuid]?.heartbeat(device)
    }

    func emitObserved(uuid: String, device: BTDevice) {
        observeRegistrations[uuid]?(device)
    }

    func emitDisconnected(uuid: String, result: BTDisconnectResult) {
        connectRegistrations[uuid]?.disconnected(result)
    }
}

private final class AdvertisementForegroundSpy: AdvertisementForegrounding {
    var observeCalls: [String] = []
    var observeRegistrations: [String: (BTDevice) -> Void] = [:]
    var invalidatedObserveUUIDs: [String] = []

    func observe<T: AnyObject>(
        _ observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken {
        observeCalls.append(uuid)
        observeRegistrations[uuid] = { [weak observer] device in
            guard let observer else { return }
            closure(observer, device)
        }
        return DaemonObservationToken { [weak self] in
            self?.invalidatedObserveUUIDs.append(uuid)
            self?.observeRegistrations.removeValue(forKey: uuid)
        }
    }

    func emitObserved(uuid: String, device: BTDevice) {
        observeRegistrations[uuid]?(device)
    }
}

private final class PropertiesForegroundSpy: PropertiesForegrounding {
    var observeCalls: [String] = []
    var observeRegistrations: [String: (BTDevice) -> Void] = [:]
    var scanRegistrations: [(BTDevice) -> Void] = []
    var invalidatedObserveUUIDs: [String] = []
    var invalidatedScanCount = 0

    func observe<T: AnyObject>(
        _ observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken {
        observeCalls.append(uuid)
        observeRegistrations[uuid] = { [weak observer] device in
            guard let observer else { return }
            closure(observer, device)
        }
        return DaemonObservationToken { [weak self] in
            self?.invalidatedObserveUUIDs.append(uuid)
            self?.observeRegistrations.removeValue(forKey: uuid)
        }
    }

    func scan<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken {
        let index = scanRegistrations.count
        scanRegistrations.append { [weak observer] device in
            guard let observer else { return }
            closure(observer, device)
        }
        return DaemonObservationToken { [weak self] in
            self?.invalidatedScanCount += 1
            if let self, self.scanRegistrations.indices.contains(index) {
                self.scanRegistrations[index] = { _ in }
            }
        }
    }

    func emitObserved(uuid: String, device: BTDevice) {
        observeRegistrations[uuid]?(device)
    }

    func emitScan(device: BTDevice) {
        scanRegistrations.forEach { $0(device) }
    }
}

private struct HeartbeatConnectionsSpy: HeartbeatConnectionsPersisting {
    let keepConnectionUUIDs: [AnyLocalIdentifier]
}

private final class HeartbeatNotificationsSpy: HeartbeatLocalNotificationsHandling {
    var didConnectUUIDs: [String] = []
    var didDisconnectUUIDs: [String] = []

    func showDidConnect(uuid: String, title: String) {
        didConnectUUIDs.append(uuid)
    }

    func showDidDisconnect(uuid: String, title: String) {
        didDisconnectUUIDs.append(uuid)
    }
}

private struct HeartbeatAlertSpy: HeartbeatAlertChecking {
    var isConnectionAlertOn: Bool = false

    func isOn(type: AlertType, for uuid: String) -> Bool {
        if case .connection = type {
            return isConnectionAlertOn
        }
        return false
    }
}

private final class HeartbeatNotifierSpy: HeartbeatNotifierHandling {
    var processedRecords: [RuuviTagSensorRecord] = []

    func process(record ruuviTag: RuuviTagSensorRecord, trigger: Bool) {
        processedRecords.append(ruuviTag)
    }
}

private final class HeartbeatReactorSpy: RuuviReactor {
    var sensorObserver: ((RuuviReactorChange<AnyRuuviTagSensor>) -> Void)?
    var sensorSettingsObservers: [String: (RuuviReactorChange<SensorSettings>) -> Void] = [:]

    func observe(
        _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensor>) -> Void
    ) -> RuuviReactorToken {
        sensorObserver = block
        return RuuviReactorToken { [weak self] in
            self?.sensorObserver = nil
        }
    }

    func observe(
        _ luid: LocalIdentifier,
        _ block: @escaping ([AnyRuuviTagSensorRecord]) -> Void
    ) -> RuuviReactorToken {
        RuuviReactorToken {}
    }

    func observeLast(
        _ ruuviTag: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void
    ) -> RuuviReactorToken {
        RuuviReactorToken {}
    }

    func observeLatest(
        _ ruuviTag: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void
    ) -> RuuviReactorToken {
        RuuviReactorToken {}
    }

    func observe(
        _ ruuviTag: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<SensorSettings>) -> Void
    ) -> RuuviReactorToken {
        sensorSettingsObservers[ruuviTag.id] = block
        return RuuviReactorToken { [weak self] in
            self?.sensorSettingsObservers.removeValue(forKey: ruuviTag.id)
        }
    }

    func emitSensors(_ change: RuuviReactorChange<AnyRuuviTagSensor>) {
        sensorObserver?(change)
    }

    func emitSensorSettings(for sensorId: String, _ change: RuuviReactorChange<SensorSettings>) {
        sensorSettingsObservers[sensorId]?(change)
    }
}

private final class LocalIDsSpy: PropertiesIDPersisting {
    var macByLuid: [String: String] = [:]
    var luidByMac: [String: String] = [:]

    func mac(for luid: LocalIdentifier) -> MACIdentifier? {
        macByLuid[luid.value]?.mac
    }

    func luid(for mac: MACIdentifier) -> LocalIdentifier? {
        luidByMac[mac.value]?.luid
    }

    func set(mac: MACIdentifier, for luid: LocalIdentifier) {
        macByLuid[luid.value] = mac.value
    }

    func set(luid: LocalIdentifier, for mac: MACIdentifier) {
        luidByMac[mac.value] = luid.value
    }
}

private final class RuuviLocalIDsProtocolStub: RuuviLocalIDs {
    private var macByLuid: [AnyLocalIdentifier: MACIdentifier] = [:]
    private var luidByMac: [AnyMACIdentifier: LocalIdentifier] = [:]

    func mac(for luid: LocalIdentifier) -> MACIdentifier? {
        macByLuid[luid.any]
    }

    func set(mac: MACIdentifier, for luid: LocalIdentifier) {
        macByLuid[luid.any] = mac
    }

    func luid(for mac: MACIdentifier) -> LocalIdentifier? {
        luidByMac[mac.any]
    }

    func extendedLuid(for mac: MACIdentifier) -> LocalIdentifier? {
        nil
    }

    func set(luid: LocalIdentifier, for mac: MACIdentifier) {
        luidByMac[mac.any] = luid
    }

    func set(extendedLuid: LocalIdentifier, for mac: MACIdentifier) {}
    func fullMac(for mac: MACIdentifier) -> MACIdentifier? { nil }
    func originalMac(for fullMac: MACIdentifier) -> MACIdentifier? { nil }
    func set(fullMac: MACIdentifier, for mac: MACIdentifier) {}
    func removeFullMac(for mac: MACIdentifier) {}
}

private final class LocalConnectionsProtocolStub: RuuviLocalConnections {
    var keepConnectionUUIDs: [AnyLocalIdentifier] = []

    func keepConnection(to luid: LocalIdentifier) -> Bool {
        keepConnectionUUIDs.contains(luid.any)
    }

    func setKeepConnection(_ value: Bool, for luid: LocalIdentifier) {}
    func unpairAllConnection() {}
}

private final class NotificationLocalProtocolStub: RuuviNotificationLocal {
    func setup(
        disableTitle: String,
        muteTitle: String,
        output: RuuviNotificationLocalOutput?
    ) {}

    func showDidConnect(uuid: String, title: String) {}
    func showDidDisconnect(uuid: String, title: String) {}
    func notifyDidMove(for uuid: String, counter: Int, title: String) {}

    func notify(
        _ reason: LowHighNotificationReason,
        _ type: AlertType,
        for uuid: String,
        title: String
    ) {}
}

private final class NotifierProtocolStub: RuuviNotifier {
    func process(record ruuviTag: RuuviTagSensorRecord, trigger: Bool) {}

    func processNetwork(
        record: RuuviTagSensorRecord,
        trigger: Bool,
        for identifier: MACIdentifier
    ) {}

    func subscribe<T>(_ observer: T, to uuid: String) where T: RuuviNotifierObserver {}

    func isSubscribed<T>(_ observer: T, to uuid: String) -> Bool where T: RuuviNotifierObserver {
        false
    }

    func clearMovementHysteresis(for uuid: String) {}
}

private final class SensorReaderSpy: PropertiesSensorReading {
    var sensorById: [String: AnyRuuviTagSensor] = [:]

    func readOne(_ id: String) async throws -> AnyRuuviTagSensor {
        sensorById[id] ?? makeSensor(id: id).any
    }
}

private final class PersistenceUnusedStub: RuuviPersistence {
    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool { true }
    func create(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool { true }
    func readAll() async throws -> [AnyRuuviTagSensor] { [] }
    func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ ruuviTagId: String, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ ruuviTagId: String, after date: Date) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTagId: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { nil }
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { nil }
    func deleteLatest(_ ruuviTagId: String) async throws -> Bool { true }
    func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor { makeSensor(id: ruuviTagId).any }
    func getStoredTagsCount() async throws -> Int { 0 }
    func getStoredMeasurementsCount() async throws -> Int { 0 }
    func read(_ ruuviTagId: String, after date: Date, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readDownsampled(_ ruuviTagId: String, after date: Date, with intervalMinutes: Int, pick points: Double) async throws -> [RuuviTagSensorRecord] { [] }
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? { nil }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
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
            pressureOffset: nil
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

private final class NoOpCloud: RuuviCloud {
    func requestCode(email: String) async throws -> String? { nil }
    func validateCode(code: String) async throws -> ValidateCodeResponse {
        ValidateCodeResponse(email: "", apiKey: "")
    }
    func deleteAccount(email: String) async throws -> Bool { true }
    func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int { 0 }
    func unregisterPNToken(token: String?, tokenId: Int?) async throws -> Bool { true }
    func listPNTokens() async throws -> [RuuviCloudPNToken] { [] }
    func loadSensors() async throws -> [AnyCloudSensor] { [] }
    func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) async throws -> [RuuviCloudSensorDense] { [] }
    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws -> [AnyRuuviTagSensorRecord] { [] }
    func claim(name: String, macId: MACIdentifier) async throws -> MACIdentifier? { nil }
    func contest(macId: MACIdentifier, secret: String) async throws -> MACIdentifier? { nil }
    func unclaim(macId: MACIdentifier, removeCloudHistory: Bool) async throws -> MACIdentifier { macId }
    func share(macId: MACIdentifier, with email: String) async throws -> ShareSensorResponse {
        ShareSensorResponse()
    }
    func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier { macId }
    func loadShared(for sensor: RuuviTagSensor) async throws -> Set<AnyShareableSensor> { [] }
    func checkOwner(macId: MACIdentifier) async throws -> (String?, String?) { (nil, nil) }
    func update(name: String, for sensor: RuuviTagSensor) async throws -> AnyRuuviTagSensor { sensor.any }
    func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("noop")
    }
    func resetImage(for macId: MACIdentifier) async throws {}
    func getCloudSettings() async throws -> RuuviCloudSettings? { nil }
    func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit { temperatureUnit }
    func set(temperatureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        temperatureAccuracy
    }
    func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit { humidityUnit }
    func set(humidityAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        humidityAccuracy
    }
    func set(pressureUnit: UnitPressure) async throws -> UnitPressure { pressureUnit }
    func set(pressureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        pressureAccuracy
    }
    func set(showAllData: Bool) async throws -> Bool { showAllData }
    func set(drawDots: Bool) async throws -> Bool { drawDots }
    func set(chartDuration: Int) async throws -> Int { chartDuration }
    func set(showMinMaxAvg: Bool) async throws -> Bool { showMinMaxAvg }
    func set(cloudMode: Bool) async throws -> Bool { cloudMode }
    func set(dashboard: Bool) async throws -> Bool { dashboard }
    func set(dashboardType: DashboardType) async throws -> DashboardType { dashboardType }
    func set(dashboardTapActionType: DashboardTapActionType) async throws -> DashboardTapActionType {
        dashboardTapActionType
    }
    func set(disableEmailAlert: Bool) async throws -> Bool { disableEmailAlert }
    func set(disablePushAlert: Bool) async throws -> Bool { disablePushAlert }
    func set(marketingPreference: Bool) async throws -> Bool { marketingPreference }
    func set(profileLanguageCode: String) async throws -> String { profileLanguageCode }
    func set(dashboardSensorOrder: [String]) async throws -> [String] { dashboardSensorOrder }
    func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws -> AnyRuuviTagSensor { sensor.any }
    func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor { sensor.any }
    func setAlert(
        type: RuuviCloudAlertType,
        settingType: RuuviCloudAlertSettingType,
        isEnabled: Bool,
        min: Double?,
        max: Double?,
        counter: Int?,
        delay: Int?,
        description: String?,
        for macId: MACIdentifier
    ) async throws {}
    func loadAlerts() async throws -> [RuuviCloudSensorAlerts] { [] }
    func executeQueuedRequest(from request: RuuviCloudQueuedRequest) async throws -> Bool { true }
}

private struct HeartbeatTitlesStub: RuuviTagHeartbeatDaemonTitles {
    let didConnect = "Connected"
    let didDisconnect = "Disconnected"
}

private struct CloudSettingsStub: RuuviCloudSettings {
    var unitTemperature: TemperatureUnit? = .celsius
    var accuracyTemperature: MeasurementAccuracyType? = .two
    var unitHumidity: HumidityUnit? = .percent
    var accuracyHumidity: MeasurementAccuracyType? = .two
    var unitPressure: UnitPressure? = .hectopascals
    var accuracyPressure: MeasurementAccuracyType? = .two
    var chartShowAllPoints: Bool? = true
    var chartDrawDots: Bool? = false
    var chartViewPeriod: Int? = 24
    var chartShowMinMaxAvg: Bool? = true
    var cloudModeEnabled: Bool? = true
    var dashboardEnabled: Bool? = true
    var dashboardType: DashboardType? = .image
    var dashboardTapActionType: DashboardTapActionType? = .card
    var pushAlertDisabled: Bool? = false
    var emailAlertDisabled: Bool? = false
    var marketingPreference: Bool? = false
    var profileLanguageCode: String? = "en"
    var dashboardSensorOrder: String? = nil
}

private final class PoolSpy: RuuviPool {
    private let lock = NSLock()
    private var _updatedSensors: [RuuviTagSensor] = []
    private var _createdSensorRecords: [RuuviTagSensorRecord] = []
    private var _createdLastRecords: [RuuviTagSensorRecord] = []
    private var _updatedLastRecords: [RuuviTagSensorRecord] = []
    private var _createRecordError: Error?
    private var _updateSensorError: Error?
    private var _deletedRecordRequests: [(id: String, date: Date)] = []
    private var _deleteAllRecordsBeforeError: Error?
    private var _onDeleteAllRecordsBefore: ((String, Date) -> Void)?

    var updatedSensors: [RuuviTagSensor] {
        withLock { _updatedSensors }
    }

    var createdSensorRecords: [RuuviTagSensorRecord] {
        withLock { _createdSensorRecords }
    }

    var createdLastRecords: [RuuviTagSensorRecord] {
        withLock { _createdLastRecords }
    }

    var updatedLastRecords: [RuuviTagSensorRecord] {
        withLock { _updatedLastRecords }
    }

    var createRecordError: Error? {
        get { withLock { _createRecordError } }
        set { withLock { _createRecordError = newValue } }
    }

    var updateSensorError: Error? {
        get { withLock { _updateSensorError } }
        set { withLock { _updateSensorError = newValue } }
    }

    var deletedRecordRequests: [(id: String, date: Date)] {
        withLock { _deletedRecordRequests }
    }

    var deleteAllRecordsBeforeError: Error? {
        get { withLock { _deleteAllRecordsBeforeError } }
        set { withLock { _deleteAllRecordsBeforeError = newValue } }
    }

    var onDeleteAllRecordsBefore: ((String, Date) -> Void)? {
        get { withLock { _onDeleteAllRecordsBefore } }
        set { withLock { _onDeleteAllRecordsBefore = newValue } }
    }

    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        let error = withLock {
            _updatedSensors.append(ruuviTag)
            return _updateSensorError
        }
        if let error {
            throw error
        }
        return true
    }
    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func create(_ record: RuuviTagSensorRecord) async throws -> Bool {
        let error = withLock {
            _createdSensorRecords.append(record)
            return _createRecordError
        }
        if let error {
            throw error
        }
        return true
    }
    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        withLock {
            _createdLastRecords.append(record)
        }
        return true
    }
    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        withLock {
            _updatedLastRecords.append(record)
        }
        return true
    }
    func deleteLast(_ ruuviTagId: String) async throws -> Bool { true }
    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool { true }

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool {
        let callback = withLock {
            _deletedRecordRequests.append((ruuviTagId, date))
            return _onDeleteAllRecordsBefore
        }
        callback?(ruuviTagId, date)
        let error = withLock { _deleteAllRecordsBeforeError }
        if let error {
            throw error
        }
        return true
    }

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
            temperatureOffset: nil,
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

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private final class StorageSpy: RuuviStorage {
    var sensors: [AnyRuuviTagSensor] = []
    var readAllError: Error?
    var sensorSettingsBySensorId: [String: SensorSettings] = [:]
    var readSensorSettingsErrorsBySensorId: [String: Error] = [:]
    var readSensorSettingsCalls: [String] = []
    var latestRecordBySensorId: [String: RuuviTagSensorRecord?] = [:]
    var readLatestErrorsBySensorId: [String: Error] = [:]
    var readLatestCalls: [String] = []

    func read(_ id: String, after date: Date, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readDownsampled(_ id: String, after date: Date, with intervalMinutes: Int, pick points: Double) async throws -> [RuuviTagSensorRecord] { [] }
    func readOne(_ id: String) async throws -> AnyRuuviTagSensor { sensors.first ?? makeSensor(id: id).any }
    func readAll(_ id: String) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ id: String, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ id: String, after date: Date) async throws -> [RuuviTagSensorRecord] { [] }

    func readAll() async throws -> [AnyRuuviTagSensor] {
        if let readAllError {
            throw readAllError
        }
        return sensors
    }

    func readLast(_ id: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { nil }
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        readLatestCalls.append(ruuviTag.id)
        if let error = readLatestErrorsBySensorId[ruuviTag.id] {
            throw error
        }
        return latestRecordBySensorId[ruuviTag.id] ?? nil
    }
    func getStoredTagsCount() async throws -> Int { sensors.count }
    func getClaimedTagsCount() async throws -> Int { 0 }
    func getOfflineTagsCount() async throws -> Int { 0 }
    func getStoredMeasurementsCount() async throws -> Int { 0 }
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        readSensorSettingsCalls.append(ruuviTag.id)
        if let error = readSensorSettingsErrorsBySensorId[ruuviTag.id] {
            throw error
        }
        return sensorSettingsBySensorId[ruuviTag.id]
    }
    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for key: String) async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for type: RuuviCloudQueuedRequestType) async throws -> [RuuviCloudQueuedRequest] { [] }
}

private final class SettingsStub: RuuviLocalSettings {
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
    var advertisementDaemonIntervalMinutes = 1
    var connectionTimeout: TimeInterval = 0
    var serviceTimeout: TimeInterval = 0
    var cardsSwipeHintWasShown = false
    var alertsMuteIntervalMinutes = 0
    var movementAlertHysteresisMinutes = 0
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
    var networkPullIntervalSeconds = 1
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

    init(
        signalVisibilityMigrationInProgress: Bool = false,
        dataPruningOffsetHours: Int = 0
    ) {
        self.signalVisibilityMigrationInProgress = signalVisibilityMigrationInProgress
        self.dataPruningOffsetHours = dataPruningOffsetHours
    }

    func movementAlertHysteresisLastEvents() -> [String: Date] { [:] }
    func setMovementAlertHysteresisLastEvents(_ values: [String: Date]) {}
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

private struct LocalSyncStateStub: RuuviLocalSyncState {
    func setSyncStatus(_ status: NetworkSyncStatus) {}
    func setSyncStatusLatestRecord(_ status: NetworkSyncStatus, for macId: MACIdentifier) {}
    func getSyncStatusLatestRecord(for macId: MACIdentifier) -> NetworkSyncStatus { .none }
    func setSyncStatusHistory(_ status: NetworkSyncStatus, for macId: MACIdentifier?) {}
    func setSyncDate(_ date: Date?, for macId: MACIdentifier?) {}
    func getSyncDate(for macId: MACIdentifier?) -> Date? { nil }
    func setGattSyncDate(_ date: Date?, for macId: MACIdentifier?) {}
    func getGattSyncDate(for macId: MACIdentifier?) -> Date? { nil }
    func setAutoGattSyncAttemptDate(_ date: Date?, for macId: MACIdentifier?) {}
    func getAutoGattSyncAttemptDate(for macId: MACIdentifier?) -> Date? { nil }
    func setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(_ logged: Bool, for macId: MACIdentifier?) {}
    func hasLoggedFirstAutoSyncGattHistoryForRuuviAir(for macId: MACIdentifier?) -> Bool { false }
    func setSyncDate(_ date: Date?) {}
    func getSyncDate() -> Date? { nil }
    func setDownloadFullHistory(for macId: MACIdentifier?, downloadFull: Bool?) {}
    func downloadFullHistory(for macId: MACIdentifier?) -> Bool? { nil }
}

private final class BackgroundTaskSchedulerSpy: BackgroundTaskScheduling {
    var launchHandler: ((BackgroundProcessingTasking) -> Void)?
    var makeRequestCalls: [String] = []
    var submittedRequests: [BackgroundProcessingRequestSpy] = []
    var submitError: Error?

    func register(
        identifier: String,
        launchHandler: @escaping (BackgroundProcessingTasking) -> Void
    ) -> Bool {
        self.launchHandler = launchHandler
        return true
    }

    func makeRequest(identifier: String) -> BackgroundProcessingRequesting {
        makeRequestCalls.append(identifier)
        return BackgroundProcessingRequestSpy(identifier: identifier)
    }

    func submit(_ request: BackgroundProcessingRequesting) throws {
        if let submitError {
            throw submitError
        }
        if let request = request as? BackgroundProcessingRequestSpy {
            submittedRequests.append(request)
        }
    }
}

private final class BackgroundProcessingRequestSpy: BackgroundProcessingRequesting {
    let identifier: String
    var requiresExternalPower = true
    var requiresNetworkConnectivity = true

    init(identifier: String) {
        self.identifier = identifier
    }
}

private final class BackgroundProcessingTaskSpy: BackgroundProcessingTasking {
    var expirationHandler: (() -> Void)?
    var completions: [Bool] = []
    var onComplete: ((Bool) -> Void)?

    func setTaskCompleted(success: Bool) {
        completions.append(success)
        onComplete?(success)
    }
}

private final class PlatformBackgroundProcessingTaskSpy: PlatformBackgroundProcessingTasking {
    var expirationHandler: (() -> Void)?
    var completedValues: [Bool] = []

    func setTaskCompleted(success: Bool) {
        completedValues.append(success)
    }
}

private final class PlatformBackgroundTaskSchedulerSpy: PlatformBackgroundTaskScheduling {
    var registerIdentifiers: [String] = []
    var launchHandler: ((PlatformBackgroundProcessingTasking) -> Void)?
    var submittedRequests: [BGProcessingTaskRequest] = []

    func register(
        identifier: String,
        launchHandler: @escaping (PlatformBackgroundProcessingTasking) -> Void
    ) -> Bool {
        registerIdentifiers.append(identifier)
        self.launchHandler = launchHandler
        return true
    }

    func submit(_ request: BGProcessingTaskRequest) throws {
        submittedRequests.append(request)
    }
}

private final class OperationQueueSpy: BackgroundOperationQueueing {
    var maxConcurrentOperationCount = 0
    var cancelAllOperationsCalls = 0
    var addedOperations: [Operation] = []
    var onAddOperations: (() -> Void)?
    private let autoCompleteLastOperation: Bool

    init(autoCompleteLastOperation: Bool = false) {
        self.autoCompleteLastOperation = autoCompleteLastOperation
    }

    func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool) {
        addedOperations = ops
        onAddOperations?()
        if autoCompleteLastOperation {
            ops.last?.completionBlock?()
        }
    }

    func cancelAllOperations() {
        cancelAllOperationsCalls += 1
        addedOperations.forEach { $0.cancel() }
    }
}

private let backgroundTaskIdentifier = "com.ruuvi.station.BackgroundProcessServiceiOS13.dataPruning"

private struct TestError: Error {}

private func makeCloudSyncWorker(
    settings: SettingsStub,
    service: CloudSyncServiceSpy
) -> RuuviDaemonCloudSyncWorker {
    RuuviDaemonCloudSyncWorker(
        localSettings: settings,
        localSyncState: LocalSyncStateStub(),
        cloudSyncService: service,
        workExecutor: { work in work() },
        delayedWorkExecutor: { _, work in
            let item = DispatchWorkItem(block: work)
            item.perform()
            return item
        }
    )
}

private func makeManager(
    sensors: [AnyRuuviTagSensor] = [makeSensor(id: "sensor-1").any],
    storageError: RuuviStorageError? = nil
) -> DataPruningOperationsManager {
    let storage = StorageSpy()
    storage.sensors = sensors
    storage.readAllError = storageError
    return DataPruningOperationsManager(
        settings: SettingsStub(dataPruningOffsetHours: 6),
        ruuviStorage: storage,
        ruuviPool: PoolSpy()
    )
}

private func makeSensor(
    id: String,
    luid: String? = nil,
    mac: String? = nil,
    serviceUUID: String? = nil,
    version: Int = 5,
    isCloudSensor: Bool = false
) -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: version,
        firmwareVersion: "1.0.0",
        luid: (luid ?? "\(id)-luid").luid,
        macId: (mac ?? "\(id)-mac").mac,
        serviceUUID: serviceUUID,
        isConnectable: true,
        name: id,
        isClaimed: true,
        isOwner: true,
        owner: "owner@example.com",
        ownersPlan: nil,
        isCloudSensor: isCloudSensor,
        canShare: false,
        sharedTo: [],
        maxHistoryDays: nil
    )
}

private func waitForThreadCancellation(_ thread: Thread, timeout: TimeInterval = 1) {
    let deadline = Date().addingTimeInterval(timeout)
    while !thread.isCancelled && Date() < deadline {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
}

private func waitUntil(
    timeout: TimeInterval = 1,
    interval: UInt64 = 20_000_000,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: @escaping @Sendable () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return
        }
        try? await Task.sleep(nanoseconds: interval)
    }
    XCTFail("Timed out waiting for condition", file: file, line: line)
}

private func waitForOperationToFinish(_ operation: RuuviDaemon.AsyncOperation, timeout: TimeInterval = 1) {
    let deadline = Date().addingTimeInterval(timeout)
    while !operation.isFinished && Date() < deadline {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
}

private func makeHeartbeatSensor(
    id: String,
    luid: String,
    mac: String,
    serviceUUID: String
) -> RuuviTagSensorStruct {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: luid.luid,
        macId: mac.mac,
        serviceUUID: serviceUUID,
        isConnectable: true,
        name: id,
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

private func makeHeartbeatSensorWithoutLuid(
    id: String,
    mac: String,
    serviceUUID: String
) -> RuuviTagSensorStruct {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: nil,
        macId: mac.mac,
        serviceUUID: serviceUUID,
        isConnectable: true,
        name: id,
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

private func makeHeartbeatDevice(uuid: String, version: Int = 5) -> BTDevice {
    .ruuvi(.tag(
        .h5(
            RuuviHeartbeat5(
                uuid: uuid,
                isConnectable: true,
                version: version,
                humidity: 64.0,
                temperature: 21.5,
                pressure: 1001.0,
                accelerationX: 1,
                accelerationY: 2,
                accelerationZ: 3,
                voltage: 2.9,
                movementCounter: 4,
                measurementSequenceNumber: 10,
                txPower: 5
            )
        )
    ))
}

private func makeC5Device(uuid: String, serviceUUID: String) -> BTDevice {
    .ruuvi(.tag(
        .vC5(
            RuuviDataC5(
                uuid: uuid,
                serviceUUID: serviceUUID,
                rssi: -42,
                isConnectable: true,
                version: 5,
                humidity: 64.0,
                temperature: 21.5,
                pressure: 1001.0,
                voltage: 2.9,
                movementCounter: 4,
                measurementSequenceNumber: 10,
                txPower: 5,
                mac: "AA:BB:CC:DD:EE:FF"
            )
        )
    ))
}

private func makeAdvertisementTag(
    uuid: String = "luid-1",
    mac: String = "AA:BB:CC:DD:EE:FF",
    version: Int = 5,
    sequence: Int? = 10,
    humidity: Double? = 64.0
) -> RuuviTag {
    .v5(
        RuuviData5(
            uuid: uuid,
            rssi: -42,
            isConnectable: true,
            version: version,
            humidity: humidity,
            temperature: 21.5,
            pressure: 1001.0,
            accelerationX: 1,
            accelerationY: 2,
            accelerationZ: 3,
            voltage: 2.9,
            movementCounter: 4,
            measurementSequenceNumber: sequence,
            txPower: 5,
            mac: mac
        )
    )
}

private func makeDevice(tag: RuuviTag) -> BTDevice {
    .ruuvi(.tag(tag))
}
