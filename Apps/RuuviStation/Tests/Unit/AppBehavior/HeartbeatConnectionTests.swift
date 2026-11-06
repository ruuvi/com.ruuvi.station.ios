import BTKit
import Foundation
import RuuviLocal
import XCTest
@testable import RuuviDaemon
@testable import station

@MainActor final class HeartbeatConnectionTests: XCTestCase {
    func testConnectionStateNotificationsOnlyFireForRegisteredAlertsAndActualTransitions() async throws {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        let connection = try XCTUnwrap(fixture.transport.connections.first)
        connection.connected(.just)
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.notifications.connected.isEmpty)
        fixture.measurements.alerts.register(type: .connection, ruuviTag: fixture.sensor)
        connection.connected(.already)
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.notifications.connected.isEmpty)
        connection.connected(.just)
        await waitForAppState("connection alert") { fixture.notifications.connected.count == 1 }
        XCTAssertEqual(fixture.notifications.connected[0].0, fixture.sensor.luid?.value)
        XCTAssertEqual(fixture.notifications.connected[0].1, "Sensor connected")
        connection.connected(.disconnected)
        await waitForAppState("peripheral disconnection alert") { fixture.notifications.disconnected.count == 1 }
        connection.disconnected(.already)
        connection.disconnected(.stillConnected)
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.notifications.disconnected.count, 1)
        connection.disconnected(.just)
        connection.disconnected(.bluetoothWasPoweredOff)
        await waitForAppState("actual disconnect alerts") { fixture.notifications.disconnected.count == 3 }
        XCTAssertEqual(fixture.notifications.disconnected.last?.1, "Sensor disconnected")
    }

    func testBluetoothFailuresAreReportedWithoutInventingAConnectionTransition() async throws {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        var errors = 0
        let token = fixture.center.addObserver(forName: .RuuviTagHeartbeatDaemonDidFail, object: nil, queue: .main) {
            _ in errors += 1
        }
        defer { fixture.center.removeObserver(token) }
        await fixture.start()
        let connection = try XCTUnwrap(fixture.transport.connections.first)
        connection.connected(.failure(.logic(.connectionTimedOut)))
        connection.disconnected(.failure(.logic(.bluetoothWasPoweredOff)))
        await waitForAppState("Bluetooth errors") { errors == 2 }
        XCTAssertTrue(fixture.notifications.connected.isEmpty)
        XCTAssertTrue(fixture.notifications.disconnected.isEmpty)
    }

    func testRemovingAndRestoringKeptConnectionCancelsThePreviousCallbacks() async throws {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        let previous = try XCTUnwrap(fixture.transport.connections.first)
        let uuid = fixture.sensor.luid!.value
        fixture.connections.setKeepConnection(false, for: fixture.sensor.luid!)
        fixture.center.post(
            name: .ConnectionPersistenceDidStopToKeepConnection, object: nil,
            userInfo: [CPDidStopToKeepConnectionKey.uuid: uuid])
        XCTAssertEqual(fixture.transport.cancelledConnections, [uuid])
        XCTAssertEqual(fixture.transport.disconnects.first?.0, uuid)
        previous.heartbeat(fixture.packet())
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.notifier.records.isEmpty)
        fixture.connections.setKeepConnection(true, for: fixture.sensor.luid!)
        fixture.center.post(
            name: .ConnectionPersistenceDidStartToKeepConnection, object: nil,
            userInfo: [CPDidStartToKeepConnectionKey.uuid: uuid])
        XCTAssertEqual(fixture.transport.connections.count, 2)
        XCTAssertEqual(fixture.transport.cancelledDisconnects, [uuid])
        fixture.emit()
        await waitForAppState("restored connection") { fixture.pool.createdLatest.count == 1 }
    }

    func testStopBeforeStartAndRepeatedStartsAreSafeAndOldCallbacksStayCancelledAfterRestart() async throws {
        let fixture = HeartbeatFixture()
        defer { fixture.cleanup() }
        fixture.worker.stop()
        await flushAppBindings()
        XCTAssertTrue(fixture.transport.disconnects.isEmpty)
        await fixture.start()
        fixture.worker.start()
        await flushAppBindings()
        XCTAssertEqual(fixture.transport.connections.count, 1)
        XCTAssertEqual(fixture.reactor.sensors.count, 1)
        let previous = try XCTUnwrap(fixture.transport.connections.first)
        fixture.worker.stop(); fixture.worker.stop()
        await waitForAppState("heartbeat stopped") { fixture.reactor.sensors.isEmpty }
        XCTAssertEqual(fixture.transport.disconnects.count, 1)
        XCTAssertTrue(fixture.reactor.settings.isEmpty)
        await fixture.start()
        previous.heartbeat(fixture.packet())
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.notifier.records.isEmpty)
        fixture.emit(fixture.packet(sequence: 2))
        await waitForAppState("new heartbeat session") { fixture.pool.createdLatest.count == 1 }
    }
}
