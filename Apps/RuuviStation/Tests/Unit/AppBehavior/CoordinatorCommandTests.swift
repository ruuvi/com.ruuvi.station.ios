import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class CoordinatorCommandTests: XCTestCase {
    func testSensorCommandsUseTheMatchingSensorAndReorderThePublishedCards() async throws {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let first = fixture.data.sensor("One")
        let second = fixture.data.sensor("Two")
        await fixture.start([first, second])
        let card = try XCTUnwrap(fixture.manager.getSnapshot(for: first.id))
        XCTAssertEqual(fixture.manager.getSensor(for: first.id)?.name, "One")
        XCTAssertEqual(Set(fixture.manager.getAllSensors().map(\.id)), Set([first.id, second.id]))
        fixture.manager.updateSensorName("Kitchen", for: card)
        await waitForAppState("name persisted") { fixture.data.properties.names.count == 1 }
        XCTAssertEqual(fixture.data.properties.names.first?.0, first.id)
        XCTAssertEqual(fixture.data.properties.names.first?.1, "Kitchen")
        fixture.manager.reorderSnapshots(with: [second.id, first.id])
        XCTAssertEqual(fixture.manager.getAllSnapshots().map(\.id), [second.id, first.id])
        fixture.data.measurements.settings.dashboardSensorOrder = [first.id, second.id]
        fixture.manager.forceReorderSnapshots()
        XCTAssertEqual(fixture.manager.getAllSnapshots().map(\.id), [first.id, second.id])
        fixture.manager.setKeepConnection(true, for: card)
        XCTAssertEqual(fixture.connections.changes.last?.0, first.luid?.value)
        XCTAssertTrue(fixture.connections.changes.last?.1 == true)
        XCTAssertTrue(fixture.manager.getConnectionStatus(for: card).keepConnection)
        fixture.manager.setKeepConnection(false, for: card)
        XCTAssertFalse(fixture.manager.getConnectionStatus(for: card).keepConnection)
    }

    func testCloudAndBluetoothEventsPreservePayloadAndReachObserversOnMainThread() async {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let observer = CoordinatorEventSpy()
        fixture.manager.addObserver(observer)
        await fixture.start([])
        await flushAppBindings(); await flushAppBindings()
        observer.events.removeAll()
        fixture.coordinator.ruuviCloudService(fixture.cloud, syncStatusDidChange: true)
        fixture.coordinator.ruuviCloudService(fixture.cloud, historySyncInProgress: true, for: "AA:01")
        fixture.coordinator.ruuviCloudService(fixture.cloud, authorizationFailed: true)
        fixture.coordinator.ruuviCloudService(fixture.cloud, cloudModeDidChange: false)
        let error = NSError(domain: "Connection", code: 42)
        fixture.coordinator.connectionService(fixture.connection, didEncounterError: error)
        fixture.coordinator.connectionService(fixture.connection, bluetoothStateChanged: false, userDeclined: true)
        await waitForAppState("service events") { observer.events.count == 6 }
        guard case .cloudSyncStatusChanged(true) = observer.events[0],
            case .historySyncInProgress(true, "AA:01") = observer.events[1],
            case .authorizationFailed = observer.events[2],
            case .cloudModeChanged(false) = observer.events[3],
            case let .connectionServiceError(received) = observer.events[4],
            case .bluetoothStateChanged(false, true) = observer.events[5]
        else { return XCTFail("Expected ordered service events with their original payload") }
        XCTAssertEqual(received as NSError, error)
        XCTAssertTrue(observer.allOnMainThread)
    }

    func testCloudIdentityAndAsynchronousManagerReadsMatchTheCurrentUser() async {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.data.sensor()
        fixture.user.email = "person@example.com"
        fixture.user.login(apiKey: "token")
        fixture.data.measurements.settings.cloudModeEnabled = true
        await fixture.start([sensor])
        XCTAssertTrue(fixture.manager.isCloudAuthorized())
        XCTAssertTrue(fixture.manager.isCloudModeEnabled())
        XCTAssertEqual(fixture.manager.getUserEmail(), "person@example.com")
        var received: [String]?
        fixture.manager.withCoordinatorAsync({ $0.getAllSensors().map(\.id) }) { ids in
            XCTAssertTrue(Thread.isMainThread)
            received = ids
        }
        await waitForAppState("async coordinator read") { received != nil }
        XCTAssertEqual(received, [sensor.id])
    }
}
