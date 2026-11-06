import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class DashboardScreenDialogTests: XCTestCase {
    func testConnectionPromptsExplainTheChoiceWithoutChangingConnectionBeforeConfirmation() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start(names: ["Office"])
        for chart in [true, false] {
            if chart {
                fixture.view.showKeepConnectionDialogChart(for: fixture.snapshots[0])
            } else {
                fixture.view.showKeepConnectionDialogSettings(for: fixture.snapshots[0], newlyAddedSensor: true)
            }
            await waitForAppState("keep connection prompt") {
                fixture.view.presentedViewController is UIAlertController
            }
            let alert = try XCTUnwrap(fixture.view.presentedViewController as? UIAlertController)
            XCTAssertEqual(alert.message, RuuviLocalization.Cards.KeepConnectionDialog.message)
            XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
            XCTAssertEqual(
                alert.actions.map(\.title),
                [
                    RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title,
                    RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title,
                ])
            XCTAssertTrue(fixture.output.connections.isEmpty)
            await withCheckedContinuation { continuation in
                fixture.view.dismiss(animated: false) { continuation.resume() }
            }
        }
    }

    func testBluetoothAndAccountDialogsExplainTheCurrentState() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start(names: [])
        for declined in [true, false] {
            fixture.view.showBluetoothDisabled(userDeclined: declined)
            await waitForAppState("Bluetooth prompt") { fixture.view.presentedViewController is UIAlertController }
            let alert = try XCTUnwrap(fixture.view.presentedViewController as? UIAlertController)
            XCTAssertEqual(alert.title, RuuviLocalization.Cards.BluetoothDisabledAlert.title)
            XCTAssertEqual(alert.message, RuuviLocalization.Cards.BluetoothDisabledAlert.message)
            XCTAssertEqual(alert.actions.map(\.style), [.default, .cancel])
            await withCheckedContinuation { continuation in
                fixture.view.dismiss(animated: false) { continuation.resume() }
            }
        }
        fixture.view.showAlreadyLoggedInAlert(with: "person@example.com")
        await waitForAppState("signed in prompt") { fixture.view.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(fixture.view.presentedViewController as? UIAlertController)
        XCTAssertTrue(alert.message?.contains("person@example.com") == true)
        XCTAssertEqual(alert.actions.count, 1)
        XCTAssertEqual(alert.actions[0].style, .cancel)
    }

    func testResettingManualOrderRequiresConfirmation() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        fixture.view.showSensorSortingResetConfirmationDialog()
        await waitForAppState("sorting reset prompt") { fixture.view.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(fixture.view.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.message, RuuviLocalization.resetOrderConfirmation)
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
        XCTAssertEqual(alert.actions.map(\.title), [RuuviLocalization.cancel, RuuviLocalization.confirm])
        XCTAssertTrue(fixture.output.orders.isEmpty)
    }
}
