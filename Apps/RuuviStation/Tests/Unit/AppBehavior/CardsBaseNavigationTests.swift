import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class CardsBaseNavigationTests: XCTestCase {
    func testAppearanceConfiguresAllChildrenWithTheSameSensorAndTab() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start(menu: .alerts)
        fixture.presenter.viewWillAppear()
        XCTAssertEqual(fixture.view.active.last, .alerts)
        XCTAssertEqual(fixture.view.lists.last, fixture.snapshots.map(\.id))
        XCTAssertEqual(fixture.view.indexes.last, 0)
        for child in [fixture.measurement, fixture.graph, fixture.alerts, fixture.settings] {
            XCTAssertEqual(child.configurations.last?.selected, fixture.snapshots[0].id)
            XCTAssertEqual(child.configurations.last?.sensor, fixture.sensors[0].id)
            XCTAssertEqual(child.configurations.last?.ids, fixture.snapshots.map(\.id))
        }
        XCTAssertTrue(fixture.measurement.measurementOutput === fixture.presenter)
        XCTAssertTrue(fixture.graph.graphOutput === fixture.presenter)
    }

    func testNavigatingEveryTabSynchronizesTheSelectedSensorAndRejectsInvalidIndexes() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        for tab: CardsMenuType in [.measurement, .graph, .alerts, .settings] {
            fixture.configure(menu: tab)
            fixture.presenter.viewShouldNavigateToSnapshotIndex(1)
            XCTAssertEqual(fixture.view.indexes.last, 1)
            for child in [fixture.measurement, fixture.graph, fixture.alerts, fixture.settings] {
                XCTAssertEqual(child.configurations.last?.selected, fixture.snapshots[1].id)
                XCTAssertEqual(child.configurations.last?.sensor, fixture.sensors[1].id)
            }
            let count = fixture.view.indexes.count
            for invalid in [-1, 2, 1] { fixture.presenter.viewShouldNavigateToSnapshotIndex(invalid) }
            XCTAssertEqual(fixture.view.indexes.count, count)
        }
        XCTAssertEqual(fixture.measurement.scrolls.map(\.1), [true, false, false, false])
        XCTAssertEqual(fixture.graph.scrolls.map(\.0), [1])
        XCTAssertEqual(fixture.alerts.starts, 1)
        XCTAssertEqual(fixture.settings.starts, 1)
    }

    func testLegacyGraphPromptsOnceAndRemembersEitherConnectionChoice() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        fixture.presenter.viewDidChangeTab(.graph)
        XCTAssertEqual(fixture.view.chartPrompts, [fixture.snapshots[0].id])
        XCTAssertTrue(fixture.graph.syncStarts.isEmpty)
        fixture.presenter.viewDidConfirmToKeepConnectionChart(to: fixture.snapshots[0])
        XCTAssertTrue(fixture.services.connections.keepConnection(to: fixture.sensors[0].luid!))
        XCTAssertEqual(fixture.graph.syncStarts, [true])
        XCTAssertEqual(fixture.view.shown.last, .graph)
        fixture.presenter.viewDidChangeTab(.measurement)
        fixture.presenter.viewDidChangeTab(.graph)
        XCTAssertEqual(fixture.view.chartPrompts.count, 1)
        fixture.configure(selected: 1)
        fixture.presenter.viewDidDismissKeepConnectionDialogChart(for: fixture.snapshots[1])
        XCTAssertFalse(fixture.services.connections.keepConnection(to: fixture.sensors[1].luid!))
        XCTAssertTrue(
            fixture.services.data.measurements.settings.keepConnectionDialogWasShown(for: fixture.sensors[1].luid!))
    }

    func testAirCloudSharedConnectedAndNonconnectableSensorsBypassTheLegacyGraphPrompt() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let snapshot = fixture.snapshots[0]
        for condition in ["air", "v6", "cloud", "shared", "connected", "nonconnectable"] {
            fixture.configure()
            snapshot.displayData.version = 5
            snapshot.metadata.isOwner = true
            snapshot.metadata.isCloud = false
            snapshot.connectionData.isConnected = false
            snapshot.connectionData.isConnectable = true
            fixture.services.data.measurements.settings.cloudModeEnabled = false
            switch condition {
            case "air": snapshot.displayData.version = 225
            case "v6": snapshot.displayData.version = 6
            case "cloud":
                snapshot.metadata.isCloud = true
                fixture.services.data.measurements.settings.cloudModeEnabled = true
            case "shared": snapshot.metadata.isOwner = false
            case "connected": snapshot.connectionData.isConnected = true
            default: snapshot.connectionData.isConnectable = false
            }
            fixture.presenter.viewDidChangeTab(.graph)
            XCTAssertEqual(fixture.view.shown.last, .graph, condition)
        }
        XCTAssertTrue(fixture.view.chartPrompts.isEmpty)
        XCTAssertEqual(fixture.graph.syncStarts, Array(repeating: true, count: 6))
    }

    func testActiveDownloadRequiresConfirmationUnlessConcurrentSyncIsEnabled() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start(menu: .graph)
        fixture.presenter.setGraphGattSyncInProgress(true)
        fixture.presenter.viewDidRequestNavigateToSnapshotIndex(1)
        fixture.presenter.viewDidTapBackButton()
        fixture.presenter.viewDidChangeTab(.measurement)
        XCTAssertEqual(fixture.graph.aborts.count, 3)
        if case .rootNavigationButton(let index) = fixture.graph.aborts[0] {
            XCTAssertEqual(index, 1)
        } else {
            XCTFail("Wrong navigation confirmation")
        }
        if case .rootBackButton = fixture.graph.aborts[1] {} else { XCTFail("Wrong back confirmation") }
        if case .topMenuSwitch = fixture.graph.aborts[2] {} else { XCTFail("Wrong tab confirmation") }
        XCTAssertEqual(fixture.output.dismissals, 0)
        fixture.services.data.measurements.flags.allowConcurrentGattSyncForMultipleSensors = true
        fixture.presenter.viewDidRequestNavigateToSnapshotIndex(1)
        fixture.presenter.viewDidTapBackButton()
        XCTAssertEqual(fixture.view.indexes.last, 1)
        XCTAssertEqual(fixture.output.dismissals, 1)
        XCTAssertEqual(fixture.graph.aborts.count, 3)
    }

    func testAbortingFromTheBackButtonCompletesDismissalWithoutShowingAnotherAbortDialog() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start(menu: .graph)
        fixture.presenter.setGraphGattSyncInProgress(true)
        fixture.presenter.graphGattSyncAborted(for: fixture.snapshots[0], source: .rootBackButton)
        XCTAssertEqual(fixture.output.dismissals, 1)
        XCTAssertTrue(fixture.graph.aborts.isEmpty)
        XCTAssertEqual(fixture.graph.stops, 1)
    }

    func testAbortNavigationAndTabSwitchResumeTheRequestedAction() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start(menu: .graph)
        fixture.presenter.graphGattSyncAborted(for: fixture.snapshots[0], source: .rootNavigationButton(1))
        XCTAssertEqual(fixture.view.indexes.last, 1)
        fixture.presenter.graphGattSyncAborted(for: fixture.snapshots[1], source: .topMenuSwitch)
        XCTAssertEqual(fixture.view.shown.last, .measurement)
        XCTAssertEqual(fixture.graph.stops, 1)
        fixture.presenter.graphGattSyncAborted(for: fixture.snapshots[1], source: .inPageCancel)
        XCTAssertEqual(fixture.graph.stops, 1)
        fixture.presenter.viewDidScrollToGraph(for: .temperature, variant: nil)
        XCTAssertEqual(fixture.graph.metrics.map(\.0), [.temperature])
    }

    func testSettingsConnectionChoicesAndFirmwareActionsUseTheSelectedSensor() async throws {
        let fixture = CardsBaseFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        fixture.presenter.viewDidConfirmToKeepConnectionSettings(to: fixture.snapshots[0])
        fixture.presenter.viewDidDismissKeepConnectionDialogSettings(for: fixture.snapshots[1])
        XCTAssertTrue(fixture.services.connections.keepConnection(to: fixture.sensors[0].luid!))
        XCTAssertFalse(fixture.services.connections.keepConnection(to: fixture.sensors[1].luid!))
        XCTAssertEqual(fixture.settings.starts, 2)
        fixture.presenter.viewDidConfirmFirmwareUpdate(for: fixture.snapshots[1])
        XCTAssertEqual(fixture.output.firmware, [fixture.sensors[1].id])
        fixture.presenter.viewDidIgnoreFirmwareUpdateDialog(for: fixture.snapshots[1])
        XCTAssertEqual(fixture.view.firmwareConfirmations, [fixture.snapshots[1].id])
        fixture.presenter.viewDidDismissFirmwareUpdateDialog(for: fixture.snapshots[1])
        XCTAssertTrue(
            fixture.services.data.measurements.settings.firmwareUpdateDialogWasShown(for: fixture.sensors[1].luid!))
        fixture.presenter.cardSettingsDidDeleteDevice(module: fixture.settings, ruuviTag: fixture.sensors[0])
        fixture.presenter.cardSettingsDidDismiss(module: fixture.settings)
        fixture.presenter.cardSettingsDidRequestOpenAlerts(module: fixture.settings)
        XCTAssertEqual(fixture.settings.stops, 1)
        XCTAssertEqual(fixture.settings.dismissals, 1)
        XCTAssertEqual(fixture.alerts.starts, 1)
    }
}
