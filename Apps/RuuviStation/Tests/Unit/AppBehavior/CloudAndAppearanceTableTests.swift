import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class CloudAndAppearanceTableTests: XCTestCase {
    func testCloudModeRowsForwardToggleChangesAndDisplayTheExplanation() async throws {
        let view = RuuviCloudTableViewController()
        let output = SettingsTableOutputSpy()
        view.output = output
        let model = RuuviCloudViewModel()
        model.title = "Cloud mode"
        model.boolean.value = false
        model.hideStatusLabel.value = false
        view.viewModels = [model]
        let host = try AppViewHost(view)
        defer { host.close() }
        view.view.layoutIfNeeded()
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(view.title, RuuviLocalization.ruuviCloud)
        let cell = try XCTUnwrap(view.tableView.cellForRow(at: .init(row: 0, section: 0)) as? RuuviCloudTableViewCell)
        XCTAssertTrue(cell.allDescendants.compactMap { ($0 as? UILabel)?.text }.contains("Cloud mode"))
        cell.didChangeSwitchState(sender: cell.statusSwitch, didToggle: true)
        XCTAssertEqual(model.boolean.value, true)
        cell.didChangeSwitchState(sender: cell.statusSwitch, didToggle: false)
        XCTAssertEqual(model.boolean.value, false)
        let footer = try XCTUnwrap(view.tableView(view.tableView, viewForFooterInSection: 0))
        XCTAssertTrue(
            footer.allDescendants.compactMap { ($0 as? UILabel)?.text }
                .contains(RuuviLocalization.Settings.Label.CloudMode.description))
        XCTAssertEqual(view.tableView(view.tableView, estimatedHeightForFooterInSection: 0), 100)
        model.hideStatusLabel.value = true
        view.viewModels = [model]
        await flushAppBindings()
        view.view.layoutIfNeeded()
        XCTAssertEqual(view.tableView.numberOfRows(inSection: 0), 1)
    }

    func testAppearanceRowsReflectTheSelectedThemeAndForwardSelection() async throws {
        let view = ASSelectionTableViewController(title: "Theme")
        let output = SettingsTableOutputSpy()
        view.output = output
        let items: [RuuviTheme] = [.system, .light, .dark]
        view.viewModel = .init(title: "Theme", items: items, selection: RuuviTheme.dark, type: .theme)
        let host = try AppViewHost(view)
        defer { host.close() }
        XCTAssertEqual(view.title, "Theme")
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(view.tableView.numberOfRows(inSection: 0), 3)
        for (index, item) in items.enumerated() {
            let path = IndexPath(row: index, section: 0)
            let cell = view.tableView(view.tableView, cellForRowAt: path)
            XCTAssertTrue(cell.allDescendants.compactMap { ($0 as? UILabel)?.text }.contains(item.title("")))
            view.tableView(view.tableView, didSelectRowAt: path)
        }
        XCTAssertEqual(output.selections.map { $0.title("") }, items.map { $0.title("") })
        view.viewModel = nil
        await flushAppBindings()
        XCTAssertEqual(view.tableView.numberOfRows(inSection: 0), 0)
    }

    func testNotificationSoundRowsShowBothChoicesAndForwardTheSelectedSound() async throws {
        let view = PushAlertSoundSelectionTableViewController(title: "Alert sound")
        let output = SettingsTableOutputSpy()
        view.output = output
        let items: [RuuviAlertSound] = [.systemDefault, .ruuviSpeak]
        view.viewModel = .init(title: "Alert sound", items: items, selection: RuuviAlertSound.ruuviSpeak)
        let host = try AppViewHost(view)
        defer { host.close() }
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(view.tableView.numberOfRows(inSection: 0), 2)
        for (index, item) in items.enumerated() {
            let path = IndexPath(row: index, section: 0)
            let cell = view.tableView(view.tableView, cellForRowAt: path)
            XCTAssertTrue(cell.allDescendants.compactMap { ($0 as? UILabel)?.text }.contains(item.title("")))
            view.tableView(view.tableView, didSelectRowAt: path)
        }
        XCTAssertEqual(output.selections.map { $0.title("") }, items.map { $0.title("") })
        view.playSelectedSound(from: .systemDefault)
        view.viewModel = nil
        await flushAppBindings()
        XCTAssertEqual(view.tableView.numberOfRows(inSection: 0), 0)
    }
}
