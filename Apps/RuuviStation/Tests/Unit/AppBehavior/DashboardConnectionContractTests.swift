import RuuviOntology
import XCTest
@testable import station

@MainActor final class DashboardConnectionContractTests: XCTestCase {
    func testConnectionNotificationsUsePersistenceAndClearStalePairingStateForOnlyTheMatchingSensor() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let snapshot = try await fixture.start()
        let luid = try XCTUnwrap(snapshot.identifierData.luid)
        fixture.presenter.viewDidLoad()
        await flushAppBindings()
        snapshot.updateConnectionData(isConnected: false, isConnectable: true, keepConnection: true)
        fixture.services.connections.setKeepConnection(true, for: luid)
        NotificationCenter.default.post(
            name: .DashboardConnectionDidChange, object: nil,
            userInfo: ["uuid": luid.value, "isConnected": true])
        XCTAssertTrue(snapshot.connectionData.isConnected)
        XCTAssertTrue(snapshot.connectionData.keepConnection)
        XCTAssertEqual(fixture.view.updates.last?.0, snapshot.id)
        fixture.services.connections.unpairAllConnection()
        NotificationCenter.default.post(
            name: .DashboardConnectionDidChange, object: nil,
            userInfo: ["uuid": luid.value, "isConnected": false])
        XCTAssertFalse(snapshot.connectionData.isConnected)
        XCTAssertFalse(
            snapshot.connectionData.keepConnection,
            "Turning background scanning off must clear the pairing spinner even if the snapshot was stale")
        let updates = fixture.view.updates.count
        let invalid: [[String: Any]] = [
            [:], ["uuid": luid.value], ["uuid": luid.value, "isConnected": "yes"],
            ["uuid": "unrelated-sensor", "isConnected": true],
        ]
        for info in invalid {
            NotificationCenter.default.post(name: .DashboardConnectionDidChange, object: nil, userInfo: info)
        }
        XCTAssertEqual(fixture.view.updates.count, updates)
        XCTAssertFalse(snapshot.connectionData.isConnected)
    }

    func testConnectionObservationDoesNotKeepADismissedDashboardAlive() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let snapshot = try await fixture.start()
        let luid = try XCTUnwrap(snapshot.identifierData.luid)
        fixture.presenter.viewDidLoad()
        await flushAppBindings()
        weak var presenter = fixture.presenter
        fixture.presenter = nil
        XCTAssertNil(presenter)
        let count = fixture.view.updates.count
        NotificationCenter.default.post(
            name: .DashboardConnectionDidChange, object: nil,
            userInfo: ["uuid": luid.value, "isConnected": true])
        XCTAssertEqual(fixture.view.updates.count, count)
    }
}
