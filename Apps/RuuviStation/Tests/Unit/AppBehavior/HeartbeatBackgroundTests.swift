import Foundation
import RuuviLocal
import RuuviOntology
import UIKit
import XCTest
@testable import RuuviDaemon
@testable import station

@MainActor final class HeartbeatBackgroundTests: XCTestCase {
    func testBackgroundAdvertisementsUseTheirSourceAndStopWhenTheAppReturnsToForeground() async throws {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        fixture.measurements.settings.appIsOnForeground = false
        await fixture.start(keepConnection: false)
        await waitForAppState("background scan") { fixture.transport.scans.count == 1 }
        let scan = try XCTUnwrap(fixture.transport.scans.first)
        XCTAssertEqual(scan.0, fixture.sensor.serviceUUID)
        scan.1(fixture.backgroundPacket())
        await waitForAppState("background advertisement saved") { fixture.pool.createdLatest.count == 1 }
        XCTAssertEqual(fixture.pool.createdRecords[0].source, .bgAdvertisement)
        XCTAssertEqual(
            fixture.cache.snapshot(matching: fixture.sensor.id)?.record?.source,
            RuuviTagSensorRecordSource.bgAdvertisement.rawValue)
        fixture.measurements.settings.appIsOnForeground = true
        fixture.center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(fixture.transport.cancelledScans.count, 1)
        scan.1(fixture.backgroundPacket(sequence: 2))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.notifier.records.count, 1)
        fixture.measurements.settings.appIsOnForeground = false
        fixture.center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertEqual(fixture.transport.scans.count, 2)
    }

    func testCloudModeConnectedSensorsAndDisabledSavingDoNotStartBackgroundScans() async {
        for condition in 0..<4 {
            let fixture = HeartbeatFixture()
            defer { fixture.cleanup() }
            fixture.measurements.settings.appIsOnForeground = false
            if condition == 0 {
                fixture.sensor.isCloudSensor = true
                fixture.measurements.settings.cloudModeEnabled = true
            } else if condition == 1 {
                fixture.transport.connectedIDs.insert(fixture.sensor.luid!.value)
            } else if condition == 2 {
                fixture.measurements.settings.saveHeartbeats = false
            } else {
                fixture.sensor.serviceUUID = nil
            }
            await fixture.start(keepConnection: false)
            XCTAssertTrue(fixture.transport.scans.isEmpty, "Condition \(condition)")
        }
    }

    func testUnsupportedBackgroundPacketsDoNotTriggerAlertsOrHistoryWrites() async throws {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        fixture.measurements.settings.appIsOnForeground = false
        await fixture.start(keepConnection: false)
        let scan = try XCTUnwrap(fixture.transport.scans.first)
        scan.1(fixture.packet())
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.notifier.records.isEmpty)
        XCTAssertTrue(fixture.pool.createdRecords.isEmpty)
    }

    func testRemovingTheSensorDropsItsWidgetConnectionsAndOldReactorCallbacks() async throws {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.emit()
        await waitForAppState("initial sensor record") { fixture.pool.createdLatest.count == 1 }
        let connection = try XCTUnwrap(fixture.transport.connections.first)
        fixture.send(.delete(fixture.sensor.any))
        await waitForAppState("deleted sensor disconnected") { fixture.transport.disconnects.count == 1 }
        XCTAssertTrue(fixture.cache.loadAll().isEmpty)
        XCTAssertTrue(fixture.reactor.settings.isEmpty)
        connection.heartbeat(fixture.packet(sequence: 2))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.pool.createdRecords.count, 1)
        fixture.send(.insert(fixture.sensor.any))
        await waitForAppState("reinserted sensor connected") { fixture.transport.connections.count == 2 }
        fixture.emit(fixture.packet(sequence: 2))
        await waitForAppState("reinserted sensor stored") { fixture.pool.createdLatest.count == 2 }
        XCTAssertEqual(fixture.cache.loadAll().count, 1)
    }

    func testSensorMetadataChangesAndStorageReloadRefreshTheWidgetAndConnections() async {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.sensor.name = "Renamed sensor"
        fixture.send(.update(fixture.sensor.any))
        await waitForAppState("renamed heartbeat sensor") {
            fixture.cache.snapshot(matching: fixture.sensor.id)?.name == "Renamed sensor"
        }
        XCTAssertEqual(fixture.transport.connections.count, 1)
        fixture.measurements.storage.sensorsOverride = []
        fixture.worker.restart()
        await waitForAppState("reload removed heartbeat sensor") { fixture.transport.disconnects.count == 1 }
        XCTAssertTrue(fixture.cache.loadAll().isEmpty)
        fixture.worker.stop()
        await flushAppBindings()
        fixture.worker.restart()
        await flushAppBindings()
        XCTAssertEqual(fixture.measurements.storage.readAllCount, 1)
    }
}
