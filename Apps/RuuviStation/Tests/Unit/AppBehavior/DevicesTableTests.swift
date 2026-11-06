import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class DevicesTableTests: XCTestCase {
    func testDeviceRowsDisplayTokenMetadataAndSelectionRoutesTheCorrectDevice() async throws {
        let view = DevicesTableViewController()
        let output = SettingsTableOutputSpy()
        view.output = output
        let known = DevicesViewModel()
        known.id.value = 123
        known.name.value = "My phone"
        known.lastAccessed.value = Date().addingTimeInterval(-3600).timeIntervalSince1970
        let missing = DevicesViewModel()
        missing.name.value = "Other phone"
        view.viewModels = [known, missing]
        let host = try AppViewHost(view)
        defer { host.close() }
        await waitForAppState("device rows loaded") { view.tableView.numberOfRows(inSection: 0) == 2 }
        view.view.layoutIfNeeded()
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(view.title, RuuviLocalization.DfuDevicesScanner.Title.text)
        let first = try XCTUnwrap(view.tableView.cellForRow(at: .init(row: 0, section: 0)) as? DevicesTableViewCell)
        let labels = first.allDescendants.compactMap { ($0 as? UILabel)?.text }
        XCTAssertTrue(labels.contains("My phone"))
        XCTAssertTrue(labels.contains("Token Id: 123"))
        XCTAssertTrue(labels.contains { $0.hasPrefix("Last accessed: ") && !$0.hasSuffix(RuuviLocalization.na) })
        let secondPath = IndexPath(row: 1, section: 0)
        view.tableView.scrollToRow(at: secondPath, at: .middle, animated: false)
        view.tableView.layoutIfNeeded()
        let second = try XCTUnwrap(view.tableView(view.tableView, cellForRowAt: secondPath) as? DevicesTableViewCell)
        let missingLabels = second.allDescendants.compactMap { ($0 as? UILabel)?.text }
        XCTAssertTrue(missingLabels.contains("Token Id: " + RuuviLocalization.na))
        XCTAssertTrue(missingLabels.contains("Last accessed: " + RuuviLocalization.na))
        view.tableView(view.tableView, didSelectRowAt: .init(row: 0, section: 0))
        XCTAssertEqual(output.devices.first?.id.value, 123)
        first.prepareForReuse()
        XCTAssertTrue(first.allDescendants.compactMap { ($0 as? UILabel)?.text }.isEmpty)
        view.viewModels = []
        await waitForAppState("device rows removed") { view.tableView.numberOfRows(inSection: 0) == 0 }
    }

    func testTokenDialogAndFetchErrorsShowTheirDetailsWithoutExposingAnEmptyToken() async throws {
        let view = DevicesTableViewController()
        let output = SettingsTableOutputSpy()
        view.output = output
        let host = try AppViewHost(view)
        defer { host.close() }
        view.showTokenIdDialog(for: DevicesViewModel())
        XCTAssertNil(view.presentedViewController)
        let model = DevicesViewModel()
        model.id.value = 123
        view.showTokenIdDialog(for: model)
        await waitForAppState("token dialog") { view.presentedViewController is UIAlertController }
        let dialog = try XCTUnwrap(view.presentedViewController as? UIAlertController)
        XCTAssertEqual(dialog.title, RuuviLocalization.Devices.tokenId)
        XCTAssertEqual(dialog.message, "123")
        XCTAssertEqual(dialog.actions.map(\.title), [RuuviLocalization.copy, RuuviLocalization.cancel])
        await withCheckedContinuation { continuation in view.dismiss(animated: false) { continuation.resume() } }
        view.showTokenFetchError(
            with: .networking(
                NSError(
                    domain: "DeviceTest", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Offline device list"])))
        await waitForAppState("device error dialog") { view.presentedViewController is UIAlertController }
        let error = try XCTUnwrap(view.presentedViewController as? UIAlertController)
        XCTAssertEqual(error.message, "Offline device list")
        XCTAssertEqual(error.actions.first?.title, RuuviLocalization.ok)
    }
}
