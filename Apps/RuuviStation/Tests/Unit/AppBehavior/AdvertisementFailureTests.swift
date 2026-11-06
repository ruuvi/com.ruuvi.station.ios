import Foundation
import RuuviOntology
import RuuviPool
import XCTest
@testable import RuuviDaemon
@testable import station

@MainActor final class AdvertisementFailureTests: XCTestCase {
    func testTemporaryStorageFailureIsReportedAndTheSamePacketCanBeRetried() async {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        var failures = 0
        let token = fixture.center.addObserver(
            forName: .RuuviTagAdvertisementDaemonDidFail, object: nil,
            queue: .main
        ) { notification in
            if notification.userInfo?[RuuviTagAdvertisementDaemonDidFailKey.error] != nil { failures += 1 }
        }
        defer { fixture.center.removeObserver(token) }
        fixture.pool.recordFailure = .ruuviPersistence(.grdb(NSError(domain: "AdvertisementTests", code: 1)))
        await fixture.start()
        fixture.emit(fixture.packet())
        await waitForAppState("storage failure notification") { failures == 1 }
        XCTAssertTrue(fixture.cancellations.isEmpty)
        fixture.pool.recordFailure = nil
        fixture.emit(fixture.packet())
        await waitForAppState("same packet retry") { fixture.pool.createdLatest.count == 1 }
        XCTAssertEqual(fixture.pool.createdRecords.count, 2)
    }

    func testStoppingWhileAHistoryWriteIsInFlightPreventsTheFollowupLatestWrite() async {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        var resume: CheckedContinuation<Void, Never>?
        fixture.pool.beforeCreateRecord = { await withCheckedContinuation { resume = $0 } }
        await fixture.start()
        fixture.emit(fixture.packet())
        await waitForAppState("history write started") { resume != nil }
        fixture.worker.stop()
        await waitForAppState("scanner stopped") { fixture.cancellations.count == 1 }
        resume?.resume(); resume = nil
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.pool.createdLatest.isEmpty)
        XCTAssertTrue(fixture.pool.updatedLatest.isEmpty)
    }

    func testDeletedCalibrationClearsTheWidgetAndAllowsTheUnchangedPacketToRefresh() async {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        let calibration = SensorSettingsStruct(
            luid: fixture.sensor.luid, macId: fixture.sensor.macId,
            temperatureOffset: 4, humidityOffset: nil, pressureOffset: nil)
        fixture.measurements.storage.settingsBySensor = [fixture.sensor.id: calibration]
        await fixture.start()
        await flushAppBindings(); await flushAppBindings()
        fixture.emit(fixture.packet())
        await waitForAppState("initial calibrated widget") {
            fixture.cache.snapshot(matching: fixture.sensor.id)?.settings?.temperatureOffset == 4
        }
        fixture.reactor.sendSettings(fixture.sensor, .delete(calibration))
        await flushAppBindings(); await flushAppBindings()
        fixture.emit(fixture.packet())
        await waitForAppState("calibration removed") { fixture.pool.createdRecords.count == 2 }
        XCTAssertNil(fixture.cache.snapshot(matching: fixture.sensor.id)?.settings)
    }
}
