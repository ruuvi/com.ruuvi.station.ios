import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class HeartbeatTableTests: XCTestCase {
    func testBackgroundScanningStateAndIntervalStayBoundToTheStoryboardControls() async throws {
        let view = try XCTUnwrap(
            UIStoryboard(name: "Heartbeat", bundle: .main)
                .instantiateViewController(withIdentifier: "HeartbeatTableViewController")
                as? HeartbeatTableViewController)
        let model = HeartbeatViewModel()
        model.bgScanningState.value = false
        model.bgScanningInterval.value = 0
        view.viewModel = model
        let host = try AppViewHost(view)
        defer { host.close() }
        await flushAppBindings()
        XCTAssertEqual(view.bgScanningTitleLabel.text, RuuviLocalization.Settings.BackgroundScanning.Bluetooth.title)
        XCTAssertEqual(view.bgScanningIntervalValueLabel.text, RuuviLocalization.Heartbeat.Interval.All.string)
        XCTAssertTrue(view.bgScannigIntervalCell.isHidden)
        XCTAssertNil(view.tableView(view.tableView, viewForFooterInSection: 0))
        model.bgScanningState.value = true
        model.bgScanningInterval.value = 5
        await waitForAppState("background scanning controls refreshed") {
            view.tableView.layoutIfNeeded()
            return !view.bgScannigIntervalCell.isHidden && view.bgScanningIntervalStepper.value == 5
        }
        XCTAssertFalse(view.bgScannigIntervalCell.isHidden)
        XCTAssertEqual(view.bgScanningIntervalStepper.value, 5)
        XCTAssertTrue(view.bgScanningIntervalValueLabel.text?.contains("5") == true)
        let footer = try XCTUnwrap(view.tableView(view.tableView, viewForFooterInSection: 0))
        XCTAssertTrue(
            footer.allDescendants.compactMap { ($0 as? UILabel)?.text }
                .contains(RuuviLocalization.Settings.BackgroundScanning.Footer.message))
        XCTAssertEqual(view.tableView(view.tableView, estimatedHeightForFooterInSection: 0), 100)
        view.bgScanningIntervalStepper.value = 10
        view.bgScanningIntervalStepperValueChanged(view.bgScanningIntervalStepper as Any)
        XCTAssertEqual(model.bgScanningInterval.value, 10)
        let replacement = HeartbeatViewModel()
        replacement.bgScanningState.value = false
        replacement.bgScanningInterval.value = 0
        view.viewModel = replacement
        await flushAppBindings()
        view.localize(); view.styleViews()
        XCTAssertEqual(view.bgScanningIntervalStepper.value, 0)
        XCTAssertTrue(view.bgScannigIntervalCell.isHidden)
    }

    func testDisablingBackgroundScanningRequiresConfirmationAndCancellationRestoresTheSwitch() async throws {
        let view = try XCTUnwrap(
            UIStoryboard(name: "Heartbeat", bundle: .main)
                .instantiateViewController(withIdentifier: "HeartbeatTableViewController")
                as? HeartbeatTableViewController)
        view.viewModel.bgScanningState.value = false
        let host = try AppViewHost(view)
        defer { host.close() }
        var pending: ((Bool) -> Void)?
        view.confirmBackgroundScanningDisable = { pending = $0 }
        view.didChangeSwitchState(sender: view.bgScanningSwitch, didToggle: true)
        XCTAssertEqual(view.viewModel.bgScanningState.value, true)
        XCTAssertNil(pending)
        view.didChangeSwitchState(sender: view.bgScanningSwitch, didToggle: false)
        XCTAssertEqual(view.viewModel.bgScanningState.value, true)
        try XCTUnwrap(pending)(false)
        XCTAssertEqual(view.viewModel.bgScanningState.value, true)
        view.didChangeSwitchState(sender: view.bgScanningSwitch, didToggle: false)
        try XCTUnwrap(pending)(true)
        XCTAssertEqual(view.viewModel.bgScanningState.value, false)
    }
}
