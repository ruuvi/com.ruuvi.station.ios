import BTKit
import RuuviLocal
import RuuviOntology
import XCTest
@testable import station

@MainActor final class ConnectionContractTests: XCTestCase {
    func testConnectionEventsKeepSensorIdentityAndOnlyPublishChangedSnapshots() async throws {
        let fixture = ConnectionContractFixture()
        let service = fixture.service
        defer { service.stopObservingConnections() }
        let card = fixture.snapshot()
        let uuid = try XCTUnwrap(card.identifierData.luid?.value)
        fixture.persistence.setKeepConnection(true, for: uuid.luid)
        service.updateConnectionData(for: card)
        await waitForAppState("initial keep connection loaded") { card.connectionData.keepConnection }
        service.startObservingConnections()
        service.startObservingConnections()
        fixture.delegate.snapshots.removeAll()
        var dashboardEvents = [(String, Bool)]()
        let token = fixture.center.addObserver(forName: .DashboardConnectionDidChange, object: nil, queue: .main) {
            event in
            if let id = event.userInfo?["uuid"] as? String, let connected = event.userInfo?["isConnected"] as? Bool {
                dashboardEvents.append((id, connected))
            }
        }
        defer { fixture.center.removeObserver(token) }
        fixture.center.post(
            name: .BTBackgroundDidConnect, object: nil, userInfo: [BTBackgroundDidConnectKey.uuid: uuid])
        XCTAssertTrue(card.connectionData.isConnected)
        XCTAssertEqual(fixture.delegate.snapshots.count, 1)
        XCTAssertTrue(fixture.delegate.snapshots[0] === card)
        fixture.center.post(
            name: .BTBackgroundDidConnect, object: nil, userInfo: [BTBackgroundDidConnectKey.uuid: uuid])
        XCTAssertEqual(fixture.delegate.snapshots.count, 1)
        fixture.center.post(
            name: .BTBackgroundDidDisconnect, object: nil, userInfo: [BTBackgroundDidDisconnectKey.uuid: uuid])
        XCTAssertFalse(card.connectionData.isConnected)
        XCTAssertEqual(fixture.delegate.snapshots.count, 2)
        XCTAssertEqual(dashboardEvents.map(\.0), [uuid, uuid, uuid])
        XCTAssertEqual(dashboardEvents.map(\.1), [true, true, false])
        fixture.center.post(name: .BTBackgroundDidConnect, object: nil, userInfo: ["wrong": uuid])
        XCTAssertEqual(dashboardEvents.count, 3)
        service.stopObservingConnections()
        fixture.center.post(
            name: .BTBackgroundDidConnect, object: nil, userInfo: [BTBackgroundDidConnectKey.uuid: uuid])
        XCTAssertFalse(card.connectionData.isConnected)
        XCTAssertEqual(dashboardEvents.count, 3)
        XCTAssertTrue(fixture.delegate.onMain)
    }

    func testKeepConnectionEventsAndUtilitiesRemainScopedToTheMatchingSensors() async throws {
        let fixture = ConnectionContractFixture()
        let service = fixture.service
        defer { service.stopObservingConnections() }
        let local = fixture.snapshot()
        let cloud = fixture.snapshot(cloud: true)
        let withoutBluetooth = fixture.snapshot(bluetooth: false)
        let localID = try XCTUnwrap(local.identifierData.luid)
        let cloudID = try XCTUnwrap(cloud.identifierData.luid)
        fixture.transport.setConnected(true, uuid: localID.value)
        service.updateConnectionData(for: [local, cloud, withoutBluetooth])
        await waitForAppState("initial connection loaded") { local.connectionData.isConnected }
        service.startObservingConnections()
        fixture.persistence.setKeepConnection(true, for: localID)
        fixture.center.post(
            name: .ConnectionPersistenceDidStartToKeepConnection, object: nil,
            userInfo: [CPDidStartToKeepConnectionKey.uuid: localID.value])
        XCTAssertTrue(local.connectionData.isConnected)
        XCTAssertTrue(local.connectionData.keepConnection)
        XCTAssertFalse(cloud.connectionData.keepConnection)
        fixture.persistence.setKeepConnection(false, for: localID)
        fixture.center.post(
            name: .ConnectionPersistenceDidStopToKeepConnection, object: nil,
            userInfo: [CPDidStopToKeepConnectionKey.uuid: localID.value])
        XCTAssertFalse(local.connectionData.keepConnection)
        service.setKeepConnection(true, for: local)
        service.setKeepConnection(true, for: cloud)
        service.setKeepConnection(true, for: withoutBluetooth)
        XCTAssertEqual(Set(service.getKeepConnectionUUIDs().map(\.value)), [localID.value, cloudID.value])
        XCTAssertEqual(service.getConnectionStatistics().connected, 1)
        XCTAssertEqual(service.getConnectionStatistics().keepConnection, 2)
        XCTAssertFalse(service.getConnectionStatus(for: withoutBluetooth).isConnected)
        service.removeConnectionsForCloudSensors(snapshots: [local, cloud, withoutBluetooth])
        XCTAssertEqual(service.getKeepConnectionUUIDs().map(\.value), [localID.value])
        service.clearAllConnections()
        XCTAssertTrue(service.getKeepConnectionUUIDs().isEmpty)
        XCTAssertEqual(service.getConnectionStatistics().connected, 0)
        XCTAssertTrue(fixture.delegate.errors.isEmpty)
    }

    func testSyncStatusUpdatesOnlyLocalSensorsAndDoesNotPublishUnchangedValues() async throws {
        let fixture = ConnectionContractFixture()
        let local = fixture.snapshot()
        let cloud = fixture.snapshot(cloud: true)
        let localMAC = try XCTUnwrap(local.identifierData.mac)
        let cloudMAC = try XCTUnwrap(cloud.identifierData.mac)
        fixture.sync.setSyncStatusLatestRecord(.complete, for: localMAC)
        fixture.sync.setSyncStatusLatestRecord(.complete, for: cloudMAC)
        fixture.service.updateNetworkSyncStatus(for: [local, cloud])
        await waitForAppState("local sync status updated") { local.displayData.networkSyncStatus == .complete }
        XCTAssertEqual(cloud.displayData.networkSyncStatus, .none)
        XCTAssertEqual(fixture.delegate.snapshots.count, 1)
        fixture.service.updateNetworkSyncStatus(for: local)
        await flushAppBindings()
        XCTAssertEqual(fixture.delegate.snapshots.count, 1)
        XCTAssertTrue(fixture.delegate.onMain)
    }

    func testBluetoothPermissionAndPowerStatesPreserveTheExistingAlertPolicy() {
        let fixture = ConnectionContractFixture()
        let local = fixture.snapshot()
        let cloud = fixture.snapshot(cloud: true)
        for state: BTScannerState in [.poweredOn, .poweredOff, .unsupported, .unauthorized, .unknown, .resetting] {
            fixture.transport.state = state
            for permission in [false, true] {
                fixture.permission = permission
                let denied = !permission || state == .unauthorized
                let enabled = denied ? state == .poweredOn : state != .poweredOff && state != .unsupported
                let current = fixture.service.getCurrentBluetoothState()
                XCTAssertEqual(current.isEnabled, enabled)
                XCTAssertEqual(current.userDeclined, denied)
                XCTAssertEqual(fixture.service.requestBluetoothPermissionIfNeeded(), permission)
                XCTAssertEqual(fixture.service.shouldShowBluetoothAlert(for: [local]), !enabled || denied)
                XCTAssertFalse(fixture.service.shouldShowBluetoothAlert(for: [cloud]))
                let count = fixture.delegate.states.count
                fixture.service.refreshBluetoothState()
                XCTAssertEqual(fixture.delegate.states.count, count + ((!enabled || denied) ? 1 : 0))
            }
        }
    }
}
