import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class DashboardDialogActionTests: XCTestCase {
    func testKeepConnectionChoicesKeepTheirSensorAndEntryPoint() async throws {
        let fixture = DashboardScreenFixture()
        try await fixture.start()
        defer { fixture.cleanup() }
        let actions = AlertActionRecorder()
        fixture.view.alertActions = actions.factory
        let card = fixture.snapshots[1]
        for route in 0..<3 {
            for keep in [false, true] {
                actions.reset()
                if route == 0 {
                    fixture.view.showKeepConnectionDialogChart(for: card)
                } else {
                    fixture.view.showKeepConnectionDialogSettings(for: card, newlyAddedSensor: route == 2)
                }
                await waitForAppState("connection dialog presented") {
                    fixture.view.presentedViewController is UIAlertController
                }
                let before = fixture.output.connections.count
                try actions.invoke(
                    keep
                        ? RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title
                        : RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title)
                XCTAssertEqual(fixture.output.connections.count, before + 1)
                let event = try XCTUnwrap(fixture.output.connections.last)
                XCTAssertEqual(event.0, (route == 0 ? "chart" : "settings") + (keep ? "-keep" : "-dismiss"))
                XCTAssertEqual(event.1, card.id)
                XCTAssertEqual(event.2, route == 2)
                await withCheckedContinuation { done in fixture.view.dismiss(animated: false) { done.resume() } }
            }
        }
    }

    func testResetOrderRequiresConfirmationAndPullToRefreshForwardsOnce() async throws {
        let fixture = DashboardScreenFixture()
        try await fixture.start()
        defer { fixture.cleanup() }
        let actions = AlertActionRecorder()
        fixture.view.alertActions = actions.factory
        fixture.view.showSensorSortingResetConfirmationDialog()
        await waitForAppState("sorting dialog presented") { fixture.view.presentedViewController is UIAlertController }
        try actions.invoke(RuuviLocalization.cancel)
        XCTAssertTrue(fixture.output.orders.isEmpty)
        await withCheckedContinuation { done in fixture.view.dismiss(animated: false) { done.resume() } }
        actions.reset()
        fixture.view.showSensorSortingResetConfirmationDialog()
        await waitForAppState("sorting dialog presented again") {
            fixture.view.presentedViewController is UIAlertController
        }
        try actions.invoke(RuuviLocalization.confirm)
        XCTAssertEqual(fixture.output.orders.count, 1)
        XCTAssertEqual(fixture.output.orders.first?.0, .alphabetical)
        XCTAssertEqual(fixture.output.orders.first?.1, [])
        let refresh = try XCTUnwrap(fixture.collection.refreshControl)
        refresh.sendActions(for: .valueChanged)
        XCTAssertEqual(fixture.output.refreshes, 0, "Refresh waits for the drag to end")
        let pan = DashboardRefreshPan()
        pan.state = .ended
        fixture.view.perform(NSSelectorFromString("handlePanGesture:"), with: pan)
        fixture.view.perform(NSSelectorFromString("handlePanGesture:"), with: pan)
        XCTAssertEqual(fixture.output.refreshes, 1)
    }
}

private final class DashboardRefreshPan: UIPanGestureRecognizer {
    private var eventState: UIGestureRecognizer.State = .possible
    override var state: UIGestureRecognizer.State {
        get { eventState }
        set { eventState = newValue }
    }
}
