import Foundation
import RuuviOntology
import RuuviPool
import XCTest
@testable import RuuviDaemon
@testable import station

@MainActor final class HeartbeatPersistenceTests: XCTestCase {
    func testHeartbeatsUpdateAlertsAndWidgetsEveryTimeButPersistEachSequenceOnlyOnce() async throws {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        fixture.measurements.storage.settingsBySensor = [fixture.sensor.id: fixture.calibration(2)]
        await fixture.start()
        fixture.emit()
        await waitForAppState("heartbeat history and latest") { fixture.pool.createdLatest.count == 1 }
        XCTAssertEqual(fixture.pool.createdRecords.count, 1)
        XCTAssertEqual(fixture.pool.createdRecords[0].source, .heartbeat)
        XCTAssertEqual(fixture.pool.createdRecords[0].temperature?.value, 20)
        XCTAssertEqual(fixture.notifier.records[0].temperature?.value, 22)
        XCTAssertEqual(fixture.notifier.triggers, [true])
        let widget = try XCTUnwrap(fixture.cache.snapshot(matching: fixture.sensor.id))
        XCTAssertEqual(widget.record?.temperature, 20)
        XCTAssertEqual(widget.record?.humidity, 0.5)
        XCTAssertEqual(widget.settings?.temperatureOffset, 2)
        fixture.emit()
        await waitForAppState("duplicate heartbeat still evaluates alerts") { fixture.notifier.records.count == 2 }
        XCTAssertEqual(fixture.pool.createdRecords.count, 1)
        fixture.emit(fixture.packet(sequence: 2))
        await waitForAppState("new heartbeat sequence") { fixture.pool.createdLatest.count == 2 }
        XCTAssertEqual(fixture.pool.createdRecords.count, 2)
    }

    func testDisablingHistoryStillEvaluatesAlertsAndUpdatesWidgets() async {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        fixture.measurements.settings.saveHeartbeats = false
        await fixture.start()
        fixture.emit()
        await waitForAppState("live heartbeat without history") { fixture.notifier.records.count == 1 }
        XCTAssertNotNil(fixture.cache.snapshot(matching: fixture.sensor.id)?.record)
        XCTAssertTrue(fixture.pool.createdRecords.isEmpty)
        XCTAssertTrue(fixture.pool.createdLatest.isEmpty)
    }

    func testForegroundAndBackgroundSamplingRespectTheirSeparateIntervals() async {
        for foreground in [true, false] {
            let fixture = HeartbeatFixture()
            defer { fixture.cleanup() }
            fixture.measurements.settings.appIsOnForeground = foreground
            fixture.measurements.settings.saveHeartbeatsForegroundIntervalSeconds = 60
            await fixture.start()
            fixture.emit()
            await waitForAppState("initial sample") { fixture.pool.createdLatest.count == 1 }
            fixture.emit(fixture.packet(sequence: 2))
            await waitForAppState("interval heartbeat evaluated") { fixture.notifier.records.count == 2 }
            XCTAssertEqual(fixture.pool.createdRecords.count, 1)
            if foreground {
                fixture.measurements.settings.saveHeartbeatsForegroundIntervalSeconds = 0
            } else {
                fixture.measurements.settings.saveHeartbeatsIntervalMinutes = 0
            }
            fixture.emit(fixture.packet(sequence: 3))
            await waitForAppState("interval change applied") { fixture.pool.createdLatest.count == 2 }
        }
    }

    func testSettingsInsertUpdateAndDeletionRecomputeAlertsAndAllowTheSameSequence() async {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.emit()
        await waitForAppState("uncalibrated sample") { fixture.pool.createdLatest.count == 1 }
        for (index, offset) in [2.0, 4.0, 0.0].enumerated() {
            let settings = fixture.calibration(offset)
            if index == 0 {
                fixture.reactor.sendSettings(fixture.sensor, .insert(settings))
            } else if index == 1 {
                fixture.reactor.sendSettings(fixture.sensor, .update(settings))
            } else {
                fixture.reactor.sendSettings(fixture.sensor, .delete(settings))
            }
            await flushAppBindings()
            fixture.emit()
            await waitForAppState("updated calibration sample") { fixture.pool.createdLatest.count == index + 2 }
            XCTAssertEqual(fixture.notifier.records.last?.temperature?.value, 20 + offset)
            XCTAssertEqual(
                fixture.cache.snapshot(matching: fixture.sensor.id)?.settings?.temperatureOffset,
                index == 2 ? nil : offset)
        }
    }

    func testStorageFailureIsReportedAndDoesNotPermanentlyDeduplicateThePacket() async {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        var failures = 0
        let token = fixture.center.addObserver(forName: .RuuviTagHeartbeatDaemonDidFail, object: nil, queue: .main) {
            _ in
            failures += 1
        }
        defer { fixture.center.removeObserver(token) }
        fixture.pool.recordFailure = .ruuviPersistence(.grdb(NSError(domain: "HeartbeatTests", code: 1)))
        await fixture.start()
        fixture.emit()
        await waitForAppState("heartbeat write failure") { failures == 1 }
        fixture.pool.recordFailure = nil
        fixture.emit()
        await waitForAppState("same heartbeat retried") { fixture.pool.createdLatest.count == 1 }
        XCTAssertEqual(fixture.pool.createdRecords.count, 2)
    }

    func testStoppingWhileHistoryWriteIsSuspendedPreventsItsFollowupLatestWrite() async {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        var continuation: CheckedContinuation<Void, Never>?
        fixture.pool.beforeCreateRecord = { await withCheckedContinuation { continuation = $0 } }
        await fixture.start()
        fixture.emit()
        await waitForAppState("suspended history write") { continuation != nil }
        fixture.worker.stop()
        await waitForAppState("stopped heartbeat") { fixture.reactor.sensors.isEmpty }
        continuation?.resume(); continuation = nil
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.pool.createdLatest.isEmpty)
    }
}
