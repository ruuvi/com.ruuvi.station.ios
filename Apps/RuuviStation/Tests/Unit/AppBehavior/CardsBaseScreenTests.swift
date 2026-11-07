import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class CardsBaseScreenTests: XCTestCase {
    func testTabsEmbedExactlyOneVisibleChildAndRequestsGoThroughThePresenter() async throws {
        let fixture = try await CardsBaseScreenFixture()
        defer { fixture.close() }
        XCTAssertEqual(fixture.view.children.count, 4)
        for tab in [CardsMenuType.measurement, .graph, .alerts, .settings] {
            fixture.view.setActiveTab(tab)
            XCTAssertEqual(fixture.output.tabs.last, tab)
            fixture.view.showContentsForTab(tab)
            await flushAppBindings()
            XCTAssertEqual(fixture.children.filter { !$0.value.view.isHidden }.map(\.key), [tab])
            XCTAssertTrue(fixture.children.values.allSatisfy { $0.parent === fixture.view })
        }
        XCTAssertGreaterThan(fixture.view.spaceUntilSecondaryToolbar, 44)
        fixture.view.setActivityIndicatorVisible(true)
        let indicator = try XCTUnwrap(
            fixture.view.view.allDescendants.compactMap { $0 as? UIActivityIndicatorView }.first)
        XCTAssertTrue(indicator.isAnimating)
        fixture.view.setActivityIndicatorVisible(false)
        XCTAssertFalse(indicator.isAnimating)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertEqual(fixture.output.foregrounds, 1)
        let back = try XCTUnwrap(
            fixture.view.view.allDescendants.compactMap { $0 as? UIButton }.first {
                $0.actions(forTarget: fixture.view, forControlEvent: .touchUpInside)?.contains("backButtonDidTap")
                    == true
            })
        back.sendActions(for: .touchUpInside)
        XCTAssertEqual(fixture.output.backs, 1)
    }

    func testSensorSwipeRespectsBothEndsAndOnlyMovesAfterPresenterApproval() async throws {
        let fixture = try await CardsBaseScreenFixture()
        defer { fixture.close() }
        let name = try XCTUnwrap(fixture.view.view.allDescendants.compactMap { $0 as? CardsSensorNameSwipeView }.first)
        XCTAssertEqual(name.text, "Office")
        XCTAssertEqual(name.onNavigate?(.previous), false)
        XCTAssertTrue(fixture.output.indices.isEmpty)
        XCTAssertEqual(name.onNavigate?(.next), false)
        XCTAssertEqual(fixture.output.indices, [1])
        XCTAssertEqual(name.text, "Office")
        fixture.output.onNavigate = { fixture.view.setActiveSnapshotIndex($0) }
        XCTAssertEqual(name.onNavigate?(.next), true)
        XCTAssertEqual(name.text, "Kitchen")
        XCTAssertEqual(name.onNavigate?(.next), false)
        XCTAssertEqual(name.onNavigate?(.previous), true)
        XCTAssertEqual(name.text, "Office")
        let previousIndices = fixture.output.indices
        fixture.view.setActiveSnapshotIndex(-1)
        fixture.view.updateTimestampLabel()
        XCTAssertEqual(name.text, "Office", "Invalid indices must not corrupt the active card")
        fixture.view.setActiveSnapshotIndex(99)
        XCTAssertEqual(name.text, "Office")
        XCTAssertEqual(fixture.output.indices, previousIndices)
    }

    func testSnapshotUpdatesRefreshOnlyTheActiveHeaderAndRetiredSnapshotsCannotOverwriteIt() async throws {
        let fixture = try await CardsBaseScreenFixture()
        defer { fixture.close() }
        let name = try XCTUnwrap(fixture.view.view.allDescendants.compactMap { $0 as? CardsSensorNameSwipeView }.first)
        fixture.snapshots[0].displayData.name = "Renamed office"
        await flushAppBindings()
        XCTAssertEqual(name.text, "Renamed office")
        fixture.view.setActiveSnapshotIndex(1)
        fixture.snapshots[0].displayData.name = "Retired header"
        await flushAppBindings()
        XCTAssertEqual(name.text, "Kitchen")
        fixture.snapshots[1].displayData.name = "Renamed kitchen"
        fixture.view.updateSnapshot(fixture.snapshots[1])
        XCTAssertEqual(name.text, "Renamed kitchen")
        fixture.view.setSnapshots([])
        fixture.view.updateTimestampLabel()
        XCTAssertTrue(
            fixture.view.view.allDescendants.compactMap { ($0 as? UILabel)?.text }
                .contains(RuuviLocalization.Cards.UpdatedLabel.NoData.message))
    }

    func testConnectionAndFirmwareDialogsExplainTheirActionAndOfferCancellation() async throws {
        let fixture = try await CardsBaseScreenFixture()
        defer { fixture.close() }
        let snapshot = fixture.snapshots[0]
        let shows: [(String, () -> Void)] = [
            (
                RuuviLocalization.Cards.KeepConnectionDialog.message,
                { fixture.view.showKeepConnectionDialogChart(for: snapshot) }
            ),
            (
                RuuviLocalization.Cards.KeepConnectionDialog.message,
                { fixture.view.showKeepConnectionDialogSettings(for: snapshot) }
            ),
            (
                RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message,
                { fixture.view.showFirmwareUpdateDialog(for: snapshot) }
            ),
            (
                RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message,
                { fixture.view.showFirmwareDismissConfirmationUpdateDialog(for: snapshot) }
            ),
        ]
        for (message, show) in shows {
            show()
            let alert = try XCTUnwrap(fixture.view.presentedViewController as? UIAlertController)
            XCTAssertEqual(alert.message, message)
            XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
            await waitForAppState("card dialog visible") { !alert.isBeingPresented && alert.view.window != nil }
            await withCheckedContinuation { continuation in
                fixture.view.dismiss(animated: false) { continuation.resume() }
            }
        }
        fixture.view.showBluetoothDisabled(userDeclined: true)
        let alert = try XCTUnwrap(fixture.view.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, RuuviLocalization.Cards.BluetoothDisabledAlert.title)
        XCTAssertEqual(alert.actions.map(\.style), [.default, .cancel])
        await waitForAppState("Bluetooth dialog visible") { !alert.isBeingPresented }
        await withCheckedContinuation { continuation in fixture.view.dismiss(animated: false) { continuation.resume() }
        }
    }
}

@MainActor final class CardsBaseScreenFixture {
    let data = SensorDataFixture()
    let children: [CardsMenuType: UIViewController] = [
        .measurement: UIViewController(), .graph: UIViewController(),
        .alerts: UIViewController(), .settings: UIViewController(),
    ]
    let output = CardsBaseScreenOutputSpy()
    let view: CardsBaseViewController
    var host: AppViewHost!
    var snapshots = [RuuviTagCardSnapshot]()
    init() async throws {
        view = CardsBaseViewController(tabs: children, activeTab: .measurement)
        let sensors = [data.sensor("Office"), data.sensor("Kitchen")]
        await data.start(sensors)
        snapshots = sensors.compactMap { data.service.getSnapshot(for: $0.id) }
        XCTAssertEqual(snapshots.count, 2)
        view.output = output
        view.setSnapshots(snapshots)
        host = try AppViewHost(view)
        view.setActiveSnapshotIndex(0)
        await waitForAppState("card attached") { self.view.view.window != nil && !self.view.isBeingPresented }
        await flushAppBindings()
    }
    func close() { output.onNavigate = nil; host.close(); data.cleanup(); data.measurements.cleanup() }
}

final class CardsBaseScreenOutputSpy: CardsBaseViewOutput {
    var tabs = [CardsMenuType]()
    var indices = [Int]()
    var foregrounds = 0
    var backs = 0
    var onNavigate: ((Int) -> Void)?
    func appWillMoveToForeground() { foregrounds += 1 }
    func viewWillAppear() {}
    func viewDidChangeTab(_ tab: CardsMenuType) { tabs.append(tab) }
    func viewDidScrollToGraph(for measurement: MeasurementType, variant: MeasurementDisplayVariant?) {}
    func viewDidRequestNavigateToSnapshotIndex(_ index: Int) { indices.append(index); onNavigate?(index) }
    func viewDidTapBackButton() { backs += 1 }
    func viewDidConfirmToKeepConnectionChart(to snapshot: RuuviTagCardSnapshot) {}
    func viewDidDismissKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot) {}
    func viewDidConfirmToKeepConnectionSettings(to snapshot: RuuviTagCardSnapshot) {}
    func viewDidDismissKeepConnectionDialogSettings(for snapshot: RuuviTagCardSnapshot) {}
    func viewDidConfirmFirmwareUpdate(for snapshot: RuuviTagCardSnapshot) {}
    func viewDidIgnoreFirmwareUpdateDialog(for snapshot: RuuviTagCardSnapshot) {}
    func viewDidDismissFirmwareUpdateDialog(for snapshot: RuuviTagCardSnapshot) {}
}
