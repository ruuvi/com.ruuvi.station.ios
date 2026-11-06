import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class CardsBaseLifecycleTests: XCTestCase {
    func testReorderPreservesSelectionAndDeletingTheCurrentSensorSelectsTheRemainingSensor() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        fixture.presenter.coordinatorDidReceiveEvent(
            fixture.services.coordinator,
            event: .snapshotsUpdated(Array(fixture.snapshots.reversed()), reason: .reorder, withAnimation: true))
        XCTAssertEqual(fixture.view.indexes.last, 1)
        XCTAssertEqual(fixture.measurement.configurations.last?.selected, fixture.snapshots[0].id)
        XCTAssertEqual(fixture.measurement.starts, 1)
        XCTAssertEqual(fixture.graph.syncStarts, [true])
        fixture.presenter.coordinatorDidReceiveEvent(
            fixture.services.coordinator,
            event: .snapshotsUpdated(
                [fixture.snapshots[1]], reason: .delete([fixture.snapshots[0]]), withAnimation: true))
        XCTAssertEqual(fixture.view.indexes.last, 0)
        XCTAssertEqual(fixture.settings.configurations.last?.selected, fixture.snapshots[1].id)
        fixture.presenter.coordinatorDidReceiveEvent(
            fixture.services.coordinator,
            event: .snapshotsUpdated([], reason: .delete([fixture.snapshots[1]]), withAnimation: true))
        XCTAssertEqual(fixture.output.dismissals, 1)
    }

    func testMetadataAndAlertUpdatesRefreshOnlyMatchingCards() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        fixture.view.updates.removeAll()
        fixture.presenter.coordinatorDidReceiveEvent(
            fixture.services.coordinator,
            event: .snapshotUpdated(fixture.snapshots[1], invalidateLayout: true))
        XCTAssertTrue(fixture.view.updates.isEmpty)
        fixture.presenter.coordinatorDidReceiveEvent(
            fixture.services.coordinator,
            event: .alertSnapshotUpdated(fixture.snapshots[0]))
        XCTAssertEqual(fixture.view.updates, [fixture.snapshots[0].id])
        XCTAssertEqual(fixture.alerts.configurations.last?.selected, fixture.snapshots[0].id)
        let count = fixture.view.lists.count
        fixture.presenter.coordinatorDidReceiveEvent(
            fixture.services.coordinator,
            event: .alertSnapshotUpdated(fixture.services.data.measurements.snapshot))
        XCTAssertEqual(fixture.view.lists.count, count)
    }

    func testClosingTheCardRejectsLateBluetoothAndCoordinatorUpdates() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        var closed = false
        fixture.presenter.dismiss { closed = true }
        XCTAssertTrue(closed)
        XCTAssertEqual(fixture.bluetoothStops, 1)
        let count = fixture.view.lists.count
        fixture.bluetooth[0](.poweredOff)
        fixture.presenter.coordinatorDidReceiveEvent(
            fixture.services.coordinator,
            event: .snapshotsUpdated(fixture.snapshots, reason: .update(fixture.snapshots), withAnimation: false))
        XCTAssertTrue(fixture.view.bluetooth.isEmpty)
        XCTAssertEqual(fixture.view.lists.count, count)
    }

    func testBluetoothWarningsDistinguishPermissionDenialAndPowerState() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        fixture.bluetooth[0](.poweredOn)
        XCTAssertTrue(fixture.view.bluetooth.isEmpty)
        fixture.bluetooth[0](.poweredOff)
        fixture.bluetooth[0](.unsupported)
        fixture.bluetooth[0](.unauthorized)
        fixture.permission = false
        fixture.bluetooth[0](.poweredOn)
        XCTAssertEqual(fixture.view.bluetooth, [false, false, true, true])
    }

    func testForegroundAndCloudHistoryActivityApplyOnlyToTheActiveGraphAndSensor() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        fixture.presenter.appWillMoveToForeground()
        XCTAssertTrue(fixture.graph.reloads.isEmpty)
        fixture.presenter.ruuviCloudService(
            fixture.services.cloud, historySyncInProgress: true,
            for: fixture.sensors[0].macId!.value)
        XCTAssertTrue(fixture.view.activity.isEmpty)
        fixture.configure(menu: .graph)
        fixture.presenter.appWillMoveToForeground()
        XCTAssertEqual(fixture.graph.reloads, [true])
        fixture.presenter.ruuviCloudService(fixture.services.cloud, historySyncInProgress: true, for: "other")
        XCTAssertTrue(fixture.view.activity.isEmpty)
        fixture.presenter.ruuviCloudService(
            fixture.services.cloud, historySyncInProgress: true,
            for: fixture.sensors[0].macId!.value)
        fixture.presenter.ruuviCloudService(fixture.services.cloud, syncStatusDidChange: false)
        XCTAssertEqual(fixture.view.activity, [true, false])
    }
}
