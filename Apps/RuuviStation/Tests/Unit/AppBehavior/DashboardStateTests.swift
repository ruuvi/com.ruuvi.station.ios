import Foundation
import RuuviDaemon
import RuuviOntology
import XCTest
@testable import station

@MainActor final class DashboardStateTests: XCTestCase {
    func testBluetoothEventDoesNotRequestAnotherBluetoothEvent() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        _ = try await fixture.start()
        let refreshes = fixture.services.connection.refreshes
        fixture.presenter.coordinatorDidReceiveEvent(
            fixture.services.coordinator, event: .bluetoothStateChanged(isEnabled: false, userDeclined: true))
        XCTAssertEqual(fixture.services.connection.refreshes, refreshes)
    }

    func testRepeatedServiceStartupDoesNotDuplicateDaemonFailureObservers() async {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        await fixture.services.start([])
        fixture.presenter.viewDidLoad()
        fixture.presenter.viewDidLoad()
        let error = NSError(domain: "DaemonFixture", code: 42)
        NotificationCenter.default.post(
            name: .RuuviTagAdvertisementDaemonDidFail, object: nil, userInfo: ["error": error])
        XCTAssertEqual(fixture.errors.errors.count, 1)
        XCTAssertEqual(fixture.errors.errors.first as NSError?, error)
        weak var released = fixture.presenter
        fixture.presenter = nil
        await flushAppBindings(); await flushAppBindings()
        XCTAssertNil(released)
        NotificationCenter.default.post(
            name: .RuuviTagAdvertisementDaemonDidFail, object: nil, userInfo: ["error": error])
        XCTAssertEqual(fixture.errors.errors.count, 1)
    }

    func testSettingsChangesPersistAndSortingUpdatesTheDisplayedOrder() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let first = fixture.services.data.sensor("Alpha")
        let second = fixture.services.data.sensor("Bravo")
        await fixture.services.start([first, second])
        fixture.presenter.viewDidChangeDashboardType(dashboardType: .simple)
        fixture.presenter.viewDidChangeDashboardType(dashboardType: .simple)
        fixture.presenter.viewDidChangeDashboardTapAction(type: .chart)
        fixture.presenter.viewDidReorderSensors(with: .manual, orderedIds: [second.id, first.id])
        await waitForAppState("dashboard preferences saved") { fixture.appSettings.calls.count == 3 }
        XCTAssertEqual(fixture.services.data.measurements.settings.dashboardType, .simple)
        XCTAssertEqual(fixture.view.dashboardType, .simple)
        XCTAssertEqual(fixture.view.dashboardTapActionType, .chart)
        XCTAssertEqual(fixture.view.dashboardSortingType, .manual)
        XCTAssertEqual(fixture.services.manager.getAllSnapshots().map(\.id), [second.id, first.id])
        fixture.presenter.viewDidReorderSensors(with: .alphabetical, orderedIds: [])
        XCTAssertEqual(fixture.services.manager.getAllSnapshots().map(\.id), [first.id, second.id])
        XCTAssertEqual(fixture.view.dashboardSortingType, .alphabetical)
        fixture.presenter.viewDidResetManualSorting()
        XCTAssertEqual(fixture.view.resets, 1)
        await flushAppBindings()
    }

    func testWidgetDestinationWaitsForItsSensorAndOpensOnlyOnce() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let card = try await fixture.start(version: 225)
        let settings = fixture.services.data.measurements.settings
        settings.dashboardTapActionType = .chart
        settings.setCardToOpenFromWidget(for: card.identifierData.mac?.value)
        let coordinator = fixture.services.coordinator
        fixture.presenter.coordinatorDidReceiveEvent(
            coordinator, event: .snapshotsUpdated([], reason: .initial, withAnimation: false))
        XCTAssertTrue(fixture.router.cards.isEmpty)
        XCTAssertNotNil(settings.cardToOpenFromWidget())
        for _ in 0..<2 {
            fixture.presenter.coordinatorDidReceiveEvent(
                coordinator, event: .snapshotsUpdated([card], reason: .update([card]), withAnimation: true))
        }
        await waitForAppState("widget card opened") { fixture.router.cards.count == 1 }
        XCTAssertEqual(fixture.router.cards.first?.id, card.id)
        XCTAssertEqual(fixture.router.cards.first?.menu, .graph)
        XCTAssertNil(settings.cardToOpenFromWidget())
        XCTAssertEqual(fixture.view.empty, [true, false, false])
    }

    func testServiceErrorsRefreshAndIndividualUpdatesReachTheView() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let card = try await fixture.start()
        let coordinator = fixture.services.coordinator
        fixture.presenter.coordinatorDidReceiveEvent(coordinator, event: .cloudSyncStatusChanged(true))
        XCTAssertTrue(fixture.view.isRefreshing)
        fixture.presenter.coordinatorDidReceiveEvent(coordinator, event: .cloudSyncStatusChanged(false))
        XCTAssertFalse(fixture.view.isRefreshing)
        fixture.presenter.coordinatorDidReceiveEvent(coordinator, event: .snapshotUpdated(card, invalidateLayout: true))
        fixture.presenter.coordinatorDidReceiveEvent(coordinator, event: .alertSnapshotUpdated(card))
        fixture.presenter.coordinatorDidReceiveEvent(coordinator, event: .connectionSnapshotUpdated(card))
        XCTAssertEqual(fixture.view.updates.map(\.0), [card.id, card.id, card.id])
        XCTAssertEqual(fixture.view.updates.map(\.1), [true, false, false])
        let error = NSError(domain: "DataFixture", code: 3)
        fixture.presenter.coordinatorDidReceiveEvent(coordinator, event: .dataServiceError(error))
        fixture.presenter.coordinatorDidReceiveEvent(coordinator, event: .connectionServiceError(error))
        XCTAssertEqual(fixture.errors.errors.count, 2)
        XCTAssertTrue(fixture.presenter.shouldDismissDiscover())
    }
}
