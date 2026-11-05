import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class GraphDialogTests: XCTestCase {
    func testDestructiveAndInformationalDialogsExplainTheRequestedAction() async throws {
        let fixture = try GraphViewFixture()
        defer { fixture.close() }
        let view = fixture.controller
        let snapshot = fixture.graph.measurements.snapshot
        let checks: [(String, [UIAlertAction.Style], () -> Void)] = [
            (
                RuuviLocalization.clearLocalHistoryDescription, [.cancel, .destructive],
                {
                    view.showClearConfirmationDialog(for: snapshot)
                }
            ),
            (
                RuuviLocalization.TagCharts.AbortSync.Alert.message, [.cancel, .destructive],
                {
                    view.showSyncAbortAlert(source: .inPageCancel)
                }
            ),
            (
                RuuviLocalization.TagCharts.Dismiss.Alert.message, [.cancel, .destructive],
                {
                    view.showSyncAbortAlert(source: .rootBackButton)
                }
            ),
            (
                RuuviLocalization.TagCharts.Dismiss.Alert.message, [.cancel, .destructive],
                {
                    view.showSyncAbortAlertForSwipe(to: 2)
                }
            ),
            (
                RuuviLocalization.gattSyncDescription, [.cancel, .default],
                {
                    view.showSyncConfirmationDialog(for: snapshot)
                }
            ),
            (RuuviLocalization.TagCharts.Dismiss.Alert.message, [.cancel], { view.showSyncInProgressDialog() }),
            (
                RuuviLocalization.TagCharts.FailedToSyncDialog.message, [.cancel, .default],
                { view.showFailedToSyncIn() }
            ),
            (RuuviLocalization.longerHistoryMessage, [.cancel], { view.showLongerHistoryDialog() }),
            (RuuviLocalization.tutorialChartLongTap, [.cancel, .default], { view.showGraphLongPressTutorialDialog() }),
            (
                RuuviLocalization.TagCharts.BluetoothDisabledAlert.message, [.default, .cancel],
                {
                    view.showBluetoothDisabled(userDeclined: true)
                }
            ),
        ]
        for (message, styles, show) in checks {
            show()
            let alert = try XCTUnwrap(view.presentedViewController as? UIAlertController)
            XCTAssertEqual(alert.message, message)
            XCTAssertEqual(alert.actions.map(\.style), styles)
            XCTAssertTrue(alert.actions.allSatisfy { !($0.title ?? "").isEmpty })
            await waitForAppState("graph alert presented") { !alert.isBeingPresented }
            await withCheckedContinuation { continuation in
                view.dismiss(animated: false) { continuation.resume() }
            }
        }
    }

    func testExportMenuBuildsAShareSheetForTheGeneratedFile() async throws {
        let fixture = try GraphViewFixture()
        defer { fixture.close() }
        try "time,temperature\n0,20\n".write(to: fixture.graph.export.url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fixture.graph.export.url) }
        fixture.perform(try fixture.action(RuuviLocalization.exportHistory))
        await waitForAppState("CSV share sheet") {
            fixture.controller.requestedShare != nil
        }
        let share = try XCTUnwrap(fixture.controller.requestedShare)
        XCTAssertEqual(fixture.graph.export.requests.first?.format, "csv")
        XCTAssertEqual(fixture.graph.activity.shown, 1)
        XCTAssertEqual(fixture.graph.activity.dismissed, 1)
        XCTAssertTrue(share.excludedActivityTypes?.contains(.assignToContact) == true)
        XCTAssertTrue(fixture.controller.graphIsVisibleForUser)
    }
}
