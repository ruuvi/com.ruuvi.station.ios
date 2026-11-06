import Foundation
import RuuviLocal
import RuuviOntology
import XCTest
@testable import RuuviDaemon
@testable import station

@MainActor final class AdvertisementLifecycleTests: XCTestCase {
    func testRepeatedStartsShareOneObservationAndStopRejectsLatePackets() async {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.worker.start()
        await flushAppBindings()
        XCTAssertEqual(fixture.reactor.sensors.count, 1)
        XCTAssertEqual(fixture.scans.count, 1)
        let previous = fixture.scans[0].1
        fixture.worker.stop()
        await waitForAppState("scanner stopped") { fixture.cancellations.count == 1 }
        XCTAssertTrue(fixture.reactor.sensors.isEmpty)
        XCTAssertTrue(fixture.reactor.settings.isEmpty)
        previous(fixture.packet())
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.pool.createdRecords.isEmpty)
        await fixture.start()
        previous(fixture.packet())
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.pool.createdRecords.isEmpty)
        fixture.emit(fixture.packet(sequence: 2))
        await waitForAppState("restarted scanner writes") { fixture.pool.createdLatest.count == 1 }
    }

    func testCloudModeCancelsCloudSensorScanningAndRejectsAnAlreadyQueuedCallback() async {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        fixture.sensor.isCloudSensor = true
        await fixture.start()
        let previous = fixture.scans[0].1
        fixture.measurements.settings.cloudModeEnabled = true
        fixture.center.post(name: .CloudModeDidChange, object: nil)
        XCTAssertEqual(fixture.cancellations.count, 1)
        let unexpectedWrite = expectation(description: "cancelled scan must not persist")
        unexpectedWrite.isInverted = true
        fixture.pool.beforeCreateRecord = { unexpectedWrite.fulfill() }
        previous(fixture.packet())
        await fulfillment(of: [unexpectedWrite], timeout: 0.15)
        fixture.pool.beforeCreateRecord = nil
        XCTAssertTrue(fixture.pool.createdRecords.isEmpty)
        fixture.measurements.settings.cloudModeEnabled = false
        fixture.center.post(name: .CloudModeDidChange, object: nil)
        XCTAssertEqual(fixture.scans.count, 2)
        fixture.emit(fixture.packet())
        await waitForAppState("local mode resumed") { fixture.pool.createdLatest.count == 1 }
    }

    func testDeletingASensorInvalidatesItsQueuedPacketsAndRemovesCachedData() async {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        let callback = fixture.scans[0].1
        fixture.send(.delete(fixture.sensor.any))
        await waitForAppState("sensor removed") { fixture.cancellations.count == 1 }
        callback(fixture.packet())
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.pool.createdRecords.isEmpty)
        XCTAssertTrue(fixture.cache.loadAll().isEmpty)
        fixture.send(.insert(fixture.sensor.any))
        await waitForAppState("sensor reinserted") { fixture.scans.count == 2 }
        fixture.emit(fixture.packet())
        await waitForAppState("new sensor record") { fixture.pool.createdLatest.count == 1 }
    }

    func testRestartReloadsCurrentStorageWithoutApplyingAResponseAfterStop() async {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.measurements.storage.sensorsOverride = []
        fixture.worker.restart()
        await waitForAppState("reload removed sensor") { fixture.cancellations.count == 1 }
        XCTAssertTrue(fixture.cache.loadAll().isEmpty)
        XCTAssertEqual(fixture.measurements.storage.readAllCount, 1)
        fixture.worker.stop()
        await flushAppBindings()
        fixture.worker.restart()
        await flushAppBindings()
        XCTAssertEqual(fixture.measurements.storage.readAllCount, 1)
    }
}
