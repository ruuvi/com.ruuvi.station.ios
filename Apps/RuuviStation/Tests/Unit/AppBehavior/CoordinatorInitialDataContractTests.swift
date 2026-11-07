import RuuviOntology
import XCTest
@testable import station

@MainActor final class CoordinatorInitialDataContractTests: XCTestCase {
    func testCoordinatorAttachingToAnAlreadyLoadedServicePublishesOneInitialListWithCurrentAuthorization() async throws
    {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.data.sensor("Already loaded", cloud: true)
        await fixture.data.start([sensor])
        fixture.user.isAuthorized = true
        let card = try XCTUnwrap(fixture.data.service.getSnapshot(for: sensor.id))
        card.ownership.isAuthorized = false
        let observer = CoordinatorEventSpy()
        fixture.coordinator.addObserver(observer)
        await waitForAppState("observer registered before coordinator starts") {
            fixture.coordinator.getObserverCount() == 1
        }
        await flushAppBindings()
        fixture.coordinator.start()
        await waitForAppState("already-loaded sensor reaches coordinator") { observer.lists.count == 1 }
        XCTAssertEqual(observer.lists.first?.0.map(\.id), [sensor.id])
        guard case .initial = observer.lists.first?.1 else { return XCTFail("Cached startup is still initial data") }
        XCTAssertEqual(observer.lists.first?.2, false)
        XCTAssertTrue(card.ownership.isAuthorized)
        fixture.coordinator.start()
        await flushAppBindings()
        XCTAssertEqual(observer.lists.count, 1)
    }

    func testNewSensorEventKeepsTheSensorAndOrderAndRefreshesItsAuthorization() async throws {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let first = fixture.data.sensor("Office", cloud: true)
        let second = fixture.data.sensor("Kitchen", cloud: true)
        await fixture.start([first, second])
        fixture.user.isAuthorized = true
        let observer = CoordinatorEventSpy()
        fixture.coordinator.addObserver(observer)
        await flushAppBindings()
        observer.events.removeAll()
        fixture.coordinator.sensorDataService(
            fixture.data.service, didAddNewSensor: second, newOrder: [second.id, first.id])
        await waitForAppState("new sensor announced") { observer.types.contains(.newSensorAdded) }
        let added = observer.events.compactMap { event -> (String, [String])? in
            guard case let .newSensorAdded(sensor, order) = event else { return nil }
            return (sensor.id, order)
        }
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.0, second.id)
        XCTAssertEqual(added.first?.1, [second.id, first.id])
        XCTAssertTrue(fixture.coordinator.getAllSnapshots().allSatisfy { $0.ownership.isAuthorized })
        XCTAssertTrue(observer.allOnMainThread)
        fixture.coordinator.stop()
        observer.events.removeAll()
        fixture.coordinator.sensorDataService(fixture.data.service, didAddNewSensor: second, newOrder: [])
        await flushAppBindings()
        XCTAssertTrue(observer.events.isEmpty)
    }
}
