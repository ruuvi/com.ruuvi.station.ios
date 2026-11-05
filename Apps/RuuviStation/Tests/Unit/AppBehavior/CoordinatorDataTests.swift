import RuuviOntology
import XCTest
@testable import station

@MainActor final class CoordinatorDataTests: XCTestCase {
    func testListEventsDistinguishInitialInsertDeleteReorderAndMixedChanges() async throws {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let observer = CoordinatorEventSpy()
        fixture.coordinator.addObserver(observer)
        await fixture.start([])
        await waitForAppState("initial empty list") { observer.lists.count == 1 }
        observer.events.removeAll()
        let first = snapshot("first", name: "One")
        let second = snapshot("second", name: "Two")
        let third = snapshot("third", name: "Three")
        let lists = [[first], [first, second], [second, first], [second], [first, third]]
        for (index, list) in lists.enumerated() {
            fixture.coordinator.sensorDataService(fixture.data.service, didUpdateSnapshots: list, withAnimation: true)
            await waitForAppState("coordinator list \(index)") { observer.lists.count == index + 1 }
        }
        XCTAssertEqual(observer.lists.map { $0.0.map(\.id) }, lists.map { $0.map(\.id) })
        XCTAssertTrue(observer.lists.allSatisfy(\.2))
        guard case .initial = observer.lists[0].1 else { return XCTFail("First load should be initial") }
        guard case let .insert(added) = observer.lists[1].1 else { return XCTFail("Expected insertion, received \(observer.lists[1].1)") }
        XCTAssertEqual(added.map(\.id), ["second"])
        guard case .reorder = observer.lists[2].1 else { return XCTFail("Expected reorder") }
        guard case let .delete(removed) = observer.lists[3].1 else { return XCTFail("Expected deletion") }
        XCTAssertEqual(removed.map(\.id), ["first"])
        guard case let .mixed(inserted, deleted, updated, reordered) = observer.lists[4].1 else {
            return XCTFail("Expected mixed insertion and deletion")
        }
        XCTAssertEqual(inserted.map(\.id), ["first", "third"])
        XCTAssertEqual(deleted.map(\.id), ["second"])
        XCTAssertTrue(updated.isEmpty)
        XCTAssertFalse(reordered)
        XCTAssertTrue(observer.allOnMainThread)
    }

    func testMutatingAnExistingSnapshotIsReportedAsAnUpdate() async {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let observer = CoordinatorEventSpy()
        fixture.coordinator.addObserver(observer)
        await fixture.start([])
        await waitForAppState("initial empty list") { observer.lists.count == 1 }
        observer.events.removeAll()
        let card = snapshot("sensor", name: "Before")
        fixture.coordinator.sensorDataService(fixture.data.service, didUpdateSnapshots: [card], withAnimation: false)
        await waitForAppState("initial card") { observer.lists.count == 1 }
        card.displayData.name = "After"
        fixture.coordinator.sensorDataService(fixture.data.service, didUpdateSnapshots: [card], withAnimation: true)
        await waitForAppState("renamed card") { observer.lists.count == 2 }
        guard case let .update(updated) = observer.lists.last?.1 else { return XCTFail("Expected changed card") }
        XCTAssertEqual(updated.map(\.id), ["sensor"])
        fixture.coordinator.sensorDataService(fixture.data.service, didUpdateSnapshots: [card], withAnimation: false)
        await waitForAppState("unchanged card") { observer.lists.count == 3 }
        guard case let .update(unchanged) = observer.lists.last?.1 else { return XCTFail("Expected no new changes") }
        XCTAssertTrue(unchanged.isEmpty)
    }

    func testNewInstanceWithSameIdentityAndChangedValuesIsReportedAsAnUpdate() async {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let observer = CoordinatorEventSpy()
        fixture.coordinator.addObserver(observer)
        await fixture.start([])
        await waitForAppState("initial empty list") { observer.lists.count == 1 }
        observer.events.removeAll()
        let first = snapshot("sensor", name: "First")
        fixture.coordinator.sensorDataService(fixture.data.service, didUpdateSnapshots: [first], withAnimation: false)
        await waitForAppState("initial card") { observer.lists.count == 1 }
        let revised = snapshot("sensor", name: "Revised")
        fixture.coordinator.sensorDataService(fixture.data.service, didUpdateSnapshots: [revised], withAnimation: false)
        await waitForAppState("revised card") { observer.lists.count == 2 }
        guard case let .update(updated) = observer.lists.last?.1 else { return XCTFail("Expected changed card") }
        XCTAssertEqual(updated.first?.displayData.name, "Revised")
    }

    func testAuthorizationAndCloudAlertCapabilityFollowLoginAndLogout() async throws {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.data.sensor("Cloud", cloud: true)
        let observer = CoordinatorEventSpy()
        fixture.coordinator.addObserver(observer)
        await fixture.start([sensor])
        let card = try XCTUnwrap(fixture.manager.getSnapshot(for: sensor.id))
        card.ownership.isOwnersPlanProPlus = true
        fixture.coordinator.ruuviCloudService(fixture.cloud, userDidLogin: true)
        await waitForAppState("logged-in card") { card.ownership.isAuthorized }
        XCTAssertTrue(card.capabilities.isCloudConnectionAlertsAvailable)
        fixture.coordinator.ruuviCloudService(fixture.cloud, userDidLogOut: true)
        await waitForAppState("logged-out card") { !card.ownership.isAuthorized }
        XCTAssertFalse(card.capabilities.isCloudConnectionAlertsAvailable)
        await waitForAppState("logout notification") { observer.types.contains(.userLogoutStateChanged) }
        XCTAssertTrue(observer.types.contains(.userLoginStateChanged))
    }

    private func snapshot(_ id: String, name: String) -> RuuviTagCardSnapshot {
        let card = RuuviTagCardSnapshot.create(
            id: id, name: name, luid: nil, mac: id.mac, serviceUUID: nil,
            isCloud: false, isOwner: true, isConnectable: false, version: 5)
        card.capabilities.isPushNotificationsAvailable = false
        card.capabilities.isPushNotificationsEnabled = false
        return card
    }
}
