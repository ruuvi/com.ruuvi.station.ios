import XCTest
@testable import station

@MainActor final class CoordinatorLifecycleTests: XCTestCase {
    func testRepeatedStartsAndObserverRegistrationDoNotDuplicateSubscriptions() async throws {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.data.sensor()
        await fixture.start([sensor])
        fixture.coordinator.start()
        XCTAssertEqual(fixture.data.reactor.sensors.count, 1)
        let observer = CoordinatorEventSpy()
        fixture.manager.addObserver(observer)
        fixture.manager.addObserver(observer)
        await waitForAppState("observer registered") { fixture.manager.observerCount == 1 }
        await waitForAppState("initial sensor delivered") { !observer.lists.isEmpty }
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(observer.lists.count, 1)
        XCTAssertEqual(observer.lists.last?.0.map(\.id), [sensor.id])
        fixture.manager.removeObserver(observer)
        await waitForAppState("observer removed") { fixture.manager.observerCount == 0 }
        fixture.coordinator.stop()
        XCTAssertTrue(fixture.data.reactor.sensors.isEmpty)
        XCTAssertTrue(fixture.data.reactor.records.isEmpty)
        XCTAssertTrue(fixture.data.reactor.settings.isEmpty)
    }

    func testResetStopsTheOwnedCoordinatorBeforeDiscardingIt() async {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        await fixture.start([fixture.data.sensor()])
        XCTAssertTrue(fixture.manager.isCoordinatorInitialized)
        fixture.manager.reset()
        await waitForAppState("manager reset") { !fixture.manager.isCoordinatorInitialized }
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.data.reactor.sensors.isEmpty)
        XCTAssertTrue(fixture.manager.getAllSnapshots().isEmpty)
    }

    func testStoppedCoordinatorIgnoresLateServiceEvents() async {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let observer = CoordinatorEventSpy()
        fixture.coordinator.addObserver(observer)
        await fixture.start([])
        await flushAppBindings(); await flushAppBindings()
        fixture.coordinator.stop()
        await flushAppBindings()
        observer.events.removeAll()
        fixture.coordinator.ruuviCloudService(fixture.cloud, cloudModeDidChange: true)
        fixture.coordinator.connectionService(fixture.connection, bluetoothStateChanged: true, userDeclined: false)
        fixture.coordinator.sensorDataService(
            fixture.data.service, didEncounterError: NSError(domain: "LateEvent", code: 1))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(observer.events.isEmpty)
    }

    func testObserverRemovalSuppressesEventsAlreadyQueuedForDelivery() async {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let observer = CoordinatorEventSpy()
        fixture.coordinator.addObserver(observer)
        await fixture.start([])
        await flushAppBindings(); await flushAppBindings()
        observer.events.removeAll()
        fixture.coordinator.ruuviCloudService(fixture.cloud, historySyncInProgress: true, for: "sensor")
        fixture.coordinator.removeObserver(observer)
        XCTAssertEqual(fixture.coordinator.getObserverCount(), 0)
        await flushAppBindings(); await flushAppBindings()
        XCTAssertFalse(observer.types.contains(.historySyncInProgress))
    }

    func testRestartDoesNotDeliverEventsFromThePreviousObservationSession() async {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        let observer = CoordinatorEventSpy()
        fixture.coordinator.addObserver(observer)
        await fixture.start([])
        await flushAppBindings(); await flushAppBindings()
        observer.events.removeAll()
        fixture.coordinator.ruuviCloudService(fixture.cloud, historySyncInProgress: true, for: "old-session")
        fixture.coordinator.stop()
        fixture.coordinator.start()
        await flushAppBindings(); await flushAppBindings()
        XCTAssertFalse(observer.types.contains(.historySyncInProgress))
    }

    func testObserverCanUnregisterDuringDeinitializationWithoutBeingRetainedByQueuedWork() async {
        let fixture = CoordinatorFixture()
        defer { fixture.cleanup() }
        var observer: SelfRemovingCoordinatorObserver? = SelfRemovingCoordinatorObserver(fixture.coordinator)
        weak var released = observer
        fixture.coordinator.addObserver(observer!)
        await waitForAppState("observer registered") { fixture.coordinator.getObserverCount() == 1 }
        observer = nil
        XCTAssertNil(released)
        await waitForAppState("observer deinitialized") { fixture.coordinator.getObserverCount() == 0 }
    }

    func testManagerAccessWithoutACoordinatorReturnsEmptyStateAndCompletesAsyncReads() async {
        let manager = RuuviTagServiceCoordinatorManager()
        XCTAssertFalse(manager.isCoordinatorInitialized)
        XCTAssertEqual(manager.observerCount, 0)
        XCTAssertTrue(manager.getAllSnapshots().isEmpty)
        XCTAssertTrue(manager.getAllSensors().isEmpty)
        XCTAssertTrue(manager.getSensorSettings().isEmpty)
        XCTAssertNil(manager.getSensor(for: "missing"))
        XCTAssertNil(manager.getSnapshot(for: "missing"))
        XCTAssertNil(manager.getSensorSettings(for: "missing"))
        XCTAssertFalse(manager.isCloudAuthorized())
        XCTAssertFalse(manager.isCloudModeEnabled())
        XCTAssertNil(manager.getUserEmail())
        var completed = false
        manager.withCoordinatorAsync({ $0.getAllSnapshots() }) { snapshots in
            XCTAssertNil(snapshots)
            XCTAssertTrue(Thread.isMainThread)
            completed = true
        }
        await waitForAppState("empty coordinator completion") { completed }
    }
}

private final class SelfRemovingCoordinatorObserver: RuuviTagServiceCoordinatorObserver {
    let coordinator: RuuviTagServiceCoordinator
    init(_ coordinator: RuuviTagServiceCoordinator) { self.coordinator = coordinator }
    deinit { coordinator.removeObserver(self) }
    func coordinatorDidReceiveEvent(_ coordinator: RuuviTagServiceCoordinator, event: RuuviTagServiceCoordinatorEvent) {
    }
}
