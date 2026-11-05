import Foundation
import RuuviOntology
import RuuviService
import XCTest
#if SWIFT_PACKAGE
    @testable import RuuviDaemonCloudSync
#else
    @testable import RuuviDaemon
#endif

@MainActor final class CloudSyncLifecycleTests: XCTestCase {
    func testRepeatedStartAndRefreshRequestsCoalesceWhileSyncIsInFlight() async {
        let service = CloudSyncServiceSpy()
        service.fullDelay = .seconds(1)
        let worker = makeWorker(service, interval: 0.01)
        defer { worker.stop() }
        worker.start()
        worker.start()
        XCTAssertTrue(worker.isRunning())
        await eventually { service.fullCalls > 0 }
        worker.refreshImmediately()
        worker.refreshImmediately()
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(service.fullCalls, 1)
        worker.stop()
        XCTAssertFalse(worker.isRunning())
        await eventually { service.fullCancelled == 1 }
        worker.stop()
    }

    func testLatestRefreshesCoalesceAndStopCancelsThemWithoutAStartedPollingLoop() async {
        let service = CloudSyncServiceSpy()
        service.latestDelay = .seconds(1)
        let worker = makeWorker(service)
        worker.refreshLatestRecord()
        worker.refreshLatestRecord()
        worker.refreshLatestRecord()
        await eventually { service.latestCalls > 0 }
        XCTAssertEqual(service.latestCalls, 1)
        XCTAssertFalse(worker.isRunning())
        worker.stop()
        await eventually { service.latestCancelled == 1 }
    }

    func testMigrationDefersFullSyncThenRetriesOnceAndSkipsLatestReadings() async {
        let service = CloudSyncServiceSpy()
        let migration = LockedMigrationFlag(true)
        let worker = makeWorker(service, migration: migration)
        defer { worker.stop() }
        worker.refreshImmediately()
        worker.refreshImmediately()
        worker.refreshLatestRecord()
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(service.fullCalls, 0)
        XCTAssertEqual(service.latestCalls, 0)
        migration.value = false
        await eventually { service.fullCalls == 1 }
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(service.fullCalls, 1)
    }

    func testStopCancelsMigrationRetryEvenWhenPollingWasNeverStarted() async {
        let service = CloudSyncServiceSpy()
        let migration = LockedMigrationFlag(true)
        let worker = makeWorker(service, migration: migration)
        worker.refreshImmediately()
        try? await Task.sleep(for: .milliseconds(5))
        worker.stop()
        migration.value = false
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(service.fullCalls, 0)
        worker.start()
        await eventually { service.fullCalls == 1 }
        worker.stop()
    }

    func testFailedRefreshDoesNotBlockTheNextRequestAndRestartCreatesANewSession() async {
        let service = CloudSyncServiceSpy()
        service.failFull = true
        let worker = makeWorker(service)
        defer { worker.stop() }
        worker.refreshImmediately()
        await eventually { service.fullCalls == 1 }
        await Task.yield()
        service.failFull = false
        worker.refreshImmediately()
        await eventually { service.fullCalls == 2 }
        worker.start()
        await eventually { service.fullCalls == 3 }
        worker.stop()
        worker.start()
        await eventually { service.fullCalls == 4 }
        XCTAssertTrue(worker.isRunning())
    }

    func testReleasingRunningWorkerCancelsItsWorkAndDoesNotLeaveAPollingLoopAlive() async {
        let service = CloudSyncServiceSpy()
        service.fullDelay = .seconds(1)
        var worker: RuuviDaemonCloudSyncWorker? = makeWorker(service, interval: 0.01)
        weak var releasedWorker = worker
        worker?.start()
        await eventually { service.fullCalls > 0 }
        worker = nil
        XCTAssertNil(releasedWorker)
        // Clean up the original implementation when this regression is run before the fix.
        releasedWorker?.stop()
        await eventually { service.fullCancelled == 1 }
    }

    func testOldCompletionCannotClearAReplacementSyncForEitherRefreshKind() async {
        for latest in [false, true] {
            let service = CloudSyncServiceSpy()
            let worker = makeWorker(service)
            defer { worker.stop() }
            var suspended = [CheckedContinuation<Void, Never>]()
            let hold: () async -> Void = {
                await withCheckedContinuation { suspended.append($0) }
            }
            if latest { service.beforeLatest = hold } else { service.beforeFull = hold }
            let refresh = { if latest { worker.refreshLatestRecord() } else { worker.refreshImmediately() } }
            let calls = { latest ? service.latestCalls : service.fullCalls }
            let finished = { latest ? service.latestFinished : service.fullFinished }
            refresh()
            await eventually { calls() == 1 && suspended.count == 1 }
            worker.stop()
            refresh()
            await eventually { calls() == 2 && suspended.count == 2 }
            guard suspended.count == 2 else {
                suspended.forEach { $0.resume() }
                continue
            }
            suspended[0].resume()
            await eventually { finished() == 1 }
            refresh()
            try? await Task.sleep(for: .milliseconds(20))
            XCTAssertEqual(calls(), 2, "The old session must not clear the replacement task")
            suspended[1].resume()
            await eventually { finished() == 2 }
            service.beforeFull = nil
            service.beforeLatest = nil
            refresh()
            await eventually { calls() == 3 }
        }
    }

    func testInvalidPollingIntervalsCannotCreateABusyLoopOrOverflowSleep() async {
        for interval in [Double.nan, .infinity, .greatestFiniteMagnitude, 0, -1] {
            let service = CloudSyncServiceSpy()
            let worker = makeWorker(service, interval: interval)
            worker.start()
            await eventually { service.fullCalls > 0 }
            try? await Task.sleep(for: .milliseconds(20))
            worker.stop()
            XCTAssertEqual(service.fullCalls, 1, "Invalid interval \(interval)")
        }
    }

    private func makeWorker(
        _ service: CloudSyncServiceSpy,
        interval: TimeInterval = 60,
        migration: LockedMigrationFlag = LockedMigrationFlag(false)
    ) -> RuuviDaemonCloudSyncWorker {
        .init(
            pullInterval: { interval }, migrationInProgress: { migration.value },
            cloudSyncService: service, retryDelay: 0.01)
    }

    private func eventually(
        file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool
    ) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Cloud sync did not reach the expected state", file: file, line: line)
    }
}

private final class LockedMigrationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Bool
    init(_ value: Bool) { stored = value }
    var value: Bool {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

@MainActor private final class CloudSyncServiceSpy: RuuviServiceCloudSync {
    var fullCalls = 0
    var latestCalls = 0
    var fullCancelled = 0
    var latestCancelled = 0
    var fullDelay: Duration = .zero
    var latestDelay: Duration = .zero
    var failFull = false
    var fullFinished = 0
    var latestFinished = 0
    var beforeFull: (() async -> Void)?
    var beforeLatest: (() async -> Void)?

    func syncAllRecords() async throws(RuuviServiceError) -> Bool {
        XCTAssertTrue(Thread.isMainThread)
        fullCalls += 1
        defer { fullFinished += 1 }
        await beforeFull?()
        if failFull { throw .failedToParseNetworkResponse }
        do { try await Task.sleep(for: fullDelay) } catch { fullCancelled += 1; return false }
        return true
    }
    func refreshLatestRecord() async throws(RuuviServiceError) -> Bool {
        XCTAssertTrue(Thread.isMainThread)
        latestCalls += 1
        defer { latestFinished += 1 }
        await beforeLatest?()
        do { try await Task.sleep(for: latestDelay) } catch { latestCancelled += 1; return false }
        return true
    }
    func syncAll() async throws(RuuviServiceError) -> Set<AnyRuuviTagSensor> { [] }
    func sync(sensor: RuuviTagSensor) async throws(RuuviServiceError) -> [AnyRuuviTagSensorRecord] { [] }
    func syncAllHistory() async throws(RuuviServiceError) -> Bool { true }
    func syncSettings() async throws(RuuviServiceError) -> RuuviCloudSettings { throw .failedToParseNetworkResponse }
    func executePendingRequests() async throws(RuuviServiceError) -> Bool { true }
}
