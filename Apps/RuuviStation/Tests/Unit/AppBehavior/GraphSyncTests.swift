import Foundation
import XCTest
@testable import station

@MainActor final class GraphSyncTests: XCTestCase {
    func testManualSyncRequiresBluetoothAndRejectsConflictingDownloads() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.presenter.viewDidStartSync(for: nil)
        for state in [(false, false), (true, true)] {
            fixture.bluetooth = state
            fixture.presenter.viewDidTriggerSync(for: fixture.measurements.snapshot)
        }
        XCTAssertEqual(fixture.view.disabledBluetooth, [false, true])
        XCTAssertTrue(fixture.view.syncConfirmations.isEmpty)
        fixture.bluetooth = (true, false)
        fixture.interactor.syncingAny = true
        fixture.presenter.viewDidTriggerSync(for: fixture.measurements.snapshot)
        XCTAssertEqual(fixture.view.inProgressDialogs, 1)
        await flushAppBindings()
        XCTAssertEqual(fixture.interactor.syncs, 0)
    }

    func testSyncProgressAndDuplicateRequestsShareOneDownloadAndRefreshAfterCompletion() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        var release: CheckedContinuation<Void, Never>?
        fixture.interactor.beforeSync = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.viewDidTriggerSync(for: fixture.measurements.snapshot)
        await waitForAppState("sync waiting") { release != nil }
        fixture.presenter.viewDidTriggerSync(for: fixture.measurements.snapshot)
        XCTAssertEqual(fixture.interactor.syncs, 1)
        XCTAssertEqual(fixture.view.syncConfirmations, [fixture.measurements.sensor.id])
        XCTAssertEqual(fixture.view.syncStates.last?.1, "connecting")
        fixture.interactor.onProgress?(.reading(42))
        await waitForAppState("reading progress") { fixture.view.syncStates.last?.1 == "reading:42" }
        XCTAssertEqual(fixture.output.syncing.last, true)
        release?.resume(); release = nil
        await waitForAppState("download completed") { fixture.view.syncStates.last?.1 == "idle" }
        XCTAssertEqual(fixture.interactor.dataStarts, 1)
        XCTAssertEqual(fixture.output.syncing.last, false)
        XCTAssertEqual(fixture.view.syncFailures, 0)
    }

    func testQueueAndFailureStatesAllowAManualRetry() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.measurements.flags.allowConcurrentGattSyncForMultipleSensors = true
        fixture.interactor.syncingAny = true
        fixture.interactor.queued = true
        fixture.interactor.failure = .bluetooth(.disconnected)
        fixture.presenter.viewDidStartSync(for: fixture.measurements.snapshot)
        XCTAssertEqual(fixture.view.syncStates.last?.1, "queued")
        await waitForAppState("sync failure") {
            fixture.view.syncFailures == 1 && fixture.view.syncStates.last?.1 == "idle"
        }
        XCTAssertEqual(fixture.interactor.dataStarts, 0)
        fixture.interactor.failure = nil
        fixture.presenter.viewDidStartSync(for: fixture.measurements.snapshot)
        await waitForAppState("retry complete") { fixture.interactor.dataStarts == 1 }
        XCTAssertEqual(fixture.interactor.syncs, 2)
    }

    func testExplicitAbortInvalidatesLateProgressAndCompletion() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        var release: CheckedContinuation<Void, Never>?
        fixture.interactor.beforeSync = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.viewDidStartSync(for: fixture.measurements.snapshot)
        await waitForAppState("pending download") { release != nil }
        fixture.presenter.viewDidConfirmAbortSync(source: .rootNavigationButton(2))
        await waitForAppState("download stopped") { fixture.interactor.stops == 1 }
        XCTAssertEqual(fixture.output.aborted.first?.0, fixture.measurements.sensor.id)
        XCTAssertEqual(fixture.output.syncing.last, false)
        XCTAssertEqual(fixture.view.progressHidden, 1)
        fixture.interactor.onProgress?(.reading(99))
        release?.resume(); release = nil
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.interactor.dataStarts, 0)
        XCTAssertEqual(fixture.view.syncStates.last?.1, "idle")
        XCTAssertEqual(fixture.view.syncFailures, 0)
    }

    func testAutomaticAirHistoryHonorsTheRecentAttemptAndSuppressionRules() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.measurements.flags.autoSyncGattHistoryForRuuviAir = true
        fixture.measurements.flags.autoSyncGattHistoryForRuuviAirMinimumLastSyncDateAgeMinutes = 10
        fixture.presenter.start(shouldSyncFromCloud: false)
        await waitForAppState("first automatic download") { fixture.interactor.syncs == 1 }
        await waitForAppState("automatic download complete") { fixture.output.syncing.last == false }
        XCTAssertTrue(fixture.interactor.logged)
        XCTAssertNotNil(fixture.interactor.attempt)
        XCTAssertTrue(fixture.view.syncConfirmations.isEmpty)
        fixture.presenter.start(shouldSyncFromCloud: false)
        try? await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(fixture.interactor.syncs, 1)
        fixture.interactor.attempt = Date().addingTimeInterval(-1200)
        fixture.interactor.suppressed = true
        fixture.presenter.start(shouldSyncFromCloud: false)
        try? await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(fixture.interactor.syncs, 1)
        fixture.interactor.suppressed = false
        fixture.interactor.failure = .bluetooth(.disconnected)
        fixture.presenter.start(shouldSyncFromCloud: false)
        await waitForAppState("automatic retry") { fixture.interactor.syncs == 2 }
        await flushAppBindings()
        XCTAssertEqual(fixture.view.syncFailures, 0)
    }

    func testStoppingBeforeAutomaticStartOrHidingTheGraphDoesNotDownloadHistory() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.measurements.flags.autoSyncGattHistoryForRuuviAir = true
        fixture.presenter.start(shouldSyncFromCloud: false)
        fixture.presenter.stop()
        try? await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(fixture.interactor.syncs, 0)
        fixture.view.graphIsVisibleForUser = false
        fixture.presenter.start(shouldSyncFromCloud: false)
        try? await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(fixture.interactor.syncs, 0)
    }
}
