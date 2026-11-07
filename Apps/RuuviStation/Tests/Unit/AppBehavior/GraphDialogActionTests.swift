import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class GraphDialogActionTests: XCTestCase {
    func testClearHistoryRequiresConfirmationAndUsesTheCurrentSensor() async throws {
        let fixture = try GraphViewFixture()
        defer { fixture.close() }
        let actions = AlertActionRecorder()
        fixture.controller.alertActions = actions.factory
        let snapshot = fixture.graph.measurements.snapshot
        fixture.controller.showClearConfirmationDialog(for: snapshot)
        await presented(fixture)
        try actions.invoke(RuuviLocalization.cancel)
        XCTAssertTrue(fixture.graph.interactor.deleted.isEmpty)
        await dismiss(fixture)
        actions.reset()
        fixture.controller.showClearConfirmationDialog(for: snapshot)
        await presented(fixture)
        try actions.invoke(RuuviLocalization.TagCharts.Clear.title)
        await waitForAppState("history cleared") { fixture.graph.interactor.deleted.count == 1 }
        XCTAssertEqual(fixture.graph.interactor.deleted, [snapshot.id])
    }

    func testAbortChoicesPreserveTheNavigationDestinationAndCancelExternalSync() async throws {
        let fixture = try GraphViewFixture()
        defer { fixture.close() }
        let actions = AlertActionRecorder()
        fixture.controller.alertActions = actions.factory
        fixture.graph.interactor.syncing = true
        fixture.graph.presenter.viewWillAppear()
        fixture.controller.showSyncAbortAlert(source: .inPageCancel)
        await presented(fixture)
        try actions.invoke(RuuviLocalization.ok)
        XCTAssertTrue(fixture.graph.output.aborted.isEmpty)
        await dismiss(fixture)
        actions.reset()
        fixture.controller.showSyncAbortAlert(source: .inPageCancel)
        await presented(fixture)
        try actions.invoke(RuuviLocalization.TagCharts.AbortSync.Button.title)
        await waitForAppState("active sync cancelled") { fixture.graph.interactor.stops == 1 }
        XCTAssertEqual(fixture.graph.output.aborted.first?.0, fixture.graph.measurements.snapshot.id)
        guard case .inPageCancel = fixture.graph.output.aborted.first?.1 else { return XCTFail("Wrong abort source") }
        await dismiss(fixture)
        actions.reset()
        fixture.controller.showSyncAbortAlertForSwipe(to: 2)
        await presented(fixture)
        try actions.invoke(RuuviLocalization.TagCharts.AbortSync.Button.title)
        guard case .rootNavigationButton(let index) = fixture.graph.output.aborted.last?.1 else {
            return XCTFail("The selected sensor destination must survive abort confirmation")
        }
        XCTAssertEqual(index, 2)
    }

    func testTutorialAndSyncConfirmationPreferencesChangeOnlyAfterChoosingDoNotShowAgain() async throws {
        let fixture = try GraphViewFixture()
        defer { fixture.close() }
        let actions = AlertActionRecorder()
        fixture.controller.alertActions = actions.factory
        let settings = fixture.graph.measurements.settings
        settings.showGraphLongPressTutorial = true
        fixture.controller.showGraphLongPressTutorialDialog()
        await presented(fixture)
        try actions.invoke(RuuviLocalization.doNotShowAgain)
        XCTAssertFalse(settings.showGraphLongPressTutorial)
        await dismiss(fixture)
        actions.reset()
        fixture.controller.showSyncConfirmationDialog(for: fixture.graph.measurements.snapshot)
        await presented(fixture)
        try actions.invoke(RuuviLocalization.doNotShowAgain)
        XCTAssertTrue(settings.syncDialogHidden(for: try XCTUnwrap(fixture.graph.measurements.sensor.luid)))
    }

    func testRetryFromFailureDialogStartsAnotherHistoryRequest() async throws {
        let fixture = try GraphViewFixture()
        defer { fixture.close() }
        let actions = AlertActionRecorder()
        fixture.controller.alertActions = actions.factory
        fixture.graph.measurements.settings.setSyncDialogHidden(
            true, for: try XCTUnwrap(fixture.graph.measurements.sensor.luid))
        fixture.controller.showFailedToSyncIn()
        await presented(fixture)
        try actions.invoke(RuuviLocalization.TagCharts.TryAgain.title)
        await waitForAppState("history retry started") { fixture.graph.interactor.syncs == 1 }
        XCTAssertTrue(fixture.graph.errors.errors.isEmpty)
    }

    private func presented(_ fixture: GraphViewFixture) async {
        await waitForAppState("graph dialog presented") {
            fixture.controller.presentedViewController is UIAlertController
        }
    }
    private func dismiss(_ fixture: GraphViewFixture) async {
        await withCheckedContinuation { done in fixture.controller.dismiss(animated: false) { done.resume() } }
    }
}
