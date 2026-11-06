import Foundation
import RuuviDaemon
import XCTest
@testable import station

@MainActor final class CardSettingsRemovalTests: XCTestCase {
    func testRemovalClearsOnlyThatSensorsSyncAndConnectionStateAndReturnsToRootWhenLastSensorIsGone() async throws {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        let sync = fixture.services.sync
        let sensor = fixture.sensor
        let luid = try XCTUnwrap(sensor.luid)
        let mac = try XCTUnwrap(sensor.macId)
        let other = "ABCDEF001122".mac
        let date = Date()
        sync.setSyncDate(date, for: mac)
        sync.setGattSyncDate(date, for: mac)
        sync.setAutoGattSyncAttemptDate(date, for: mac)
        sync.setSyncDate(date)
        sync.setSyncDate(date, for: other)
        fixture.measurements.settings.setOwnerCheckDate(for: mac, value: date)
        fixture.services.connections.setKeepConnection(true, for: luid)
        fixture.snapshot.connectionData.isConnected = true
        var heartbeats = 0
        var advertisements = 0
        let heartbeat = fixture.center.addObserver(
            forName: .RuuviTagHeartBeatDaemonShouldRestart, object: nil, queue: nil
        ) { _ in heartbeats += 1 }
        let advertisement = fixture.center.addObserver(
            forName: .RuuviTagAdvertisementDaemonShouldRestart, object: nil, queue: nil
        ) { _ in advertisements += 1 }
        defer { fixture.center.removeObserver(heartbeat); fixture.center.removeObserver(advertisement) }
        let module = SensorRemovalModuleSpy()
        fixture.presenter.sensorRemovalDidRemoveTag(module: module, ruuviTag: sensor)
        XCTAssertEqual(module.dismissals, 1)
        XCTAssertEqual(fixture.output.deletions, [sensor.id])
        XCTAssertEqual(fixture.router.paths.map(\.0), ["root"])
        XCTAssertFalse(fixture.services.connections.keepConnection(to: luid))
        XCTAssertNil(sync.getSyncDate(for: mac))
        XCTAssertNil(sync.getGattSyncDate(for: mac))
        XCTAssertNil(sync.getAutoGattSyncAttemptDate(for: mac))
        XCTAssertNil(sync.getSyncDate())
        XCTAssertEqual(sync.getSyncDate(for: other), date)
        XCTAssertNil(fixture.measurements.settings.ownerCheckDate(for: mac))
        XCTAssertEqual(heartbeats, 2)
        XCTAssertEqual(advertisements, 1)
        XCTAssertEqual(fixture.view.stops, 1)
        await flushAppBindings()
    }

    func testRemovingOneOfSeveralSensorsKeepsTheCardFlowAndCancellationOnlyDismisses() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        await fixture.services.start([fixture.services.data.sensor("Remaining sensor")])
        let module = SensorRemovalModuleSpy()
        fixture.presenter.sensorRemovalDidRemoveTag(module: module, ruuviTag: fixture.sensor)
        XCTAssertEqual(fixture.output.deletions, [fixture.sensor.id])
        XCTAssertFalse(fixture.router.paths.contains { $0.0 == "root" })
        fixture.presenter.sensorRemovalDidDismiss(module: module)
        XCTAssertEqual(fixture.output.dismissals, 1)
        XCTAssertEqual(module.dismissals, 2)
    }

    func testKeepConnectionTimeoutRestoresTheSwitchUnlessTheSensorConnectedInTime() async {
        for connected in [false, true] {
            let fixture = CardSettingsFixture()
            defer { fixture.cleanup() }
            fixture.presenter.keepConnectionTimeout = 0.01
            fixture.presenter.viewDidTriggerKeepConnection(isOn: true)
            fixture.snapshot.connectionData.isConnected = connected
            await waitForAppState("connection timer completed") { fixture.view.stops == 1 }
            XCTAssertEqual(fixture.view.timeouts, connected ? 0 : 1)
            XCTAssertEqual(fixture.services.connections.keepConnection(to: fixture.sensor.luid!), connected)
            XCTAssertEqual(fixture.view.resets, connected ? 0 : 1)
        }
    }
}
