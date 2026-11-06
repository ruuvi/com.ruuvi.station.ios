import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class DefaultsTableTests: XCTestCase {
    func testStoryboardRowsRenderPlainSwitchAndStepperValuesAndUpdateTheirModels() throws {
        let view = try controller()
        let plain = model("Version", type: .plain)
        plain.value.value = "3.1"
        let toggle = model("Feature", type: .switcher)
        toggle.boolean.value = true
        let interval = model("Interval", type: .stepper)
        interval.integer.value = 30
        interval.unit = .seconds
        view.viewModels = [plain, toggle, interval]
        let host = try AppViewHost(view)
        defer { host.close() }
        view.view.layoutIfNeeded()
        XCTAssertEqual(view.tableView.numberOfRows(inSection: 0), 3)
        let value = try XCTUnwrap(
            view.tableView.cellForRow(at: .init(row: 0, section: 0)) as? DefaultsPlainTableViewCell)
        XCTAssertEqual(value.titleLabel.text, "Version")
        XCTAssertEqual(value.valueLabel.text, "3.1")
        let switchCell = try XCTUnwrap(
            view.tableView.cellForRow(at: .init(row: 1, section: 0)) as? DefaultsSwitchTableViewCell)
        XCTAssertEqual(switchCell.titleLabel.text, "Feature")
        switchCell.didChangeSwitchState(sender: switchCell.isOnSwitch, didToggle: false)
        XCTAssertEqual(toggle.boolean.value, false)
        let stepper = try XCTUnwrap(
            view.tableView.cellForRow(at: .init(row: 2, section: 0)) as? DefaultsStepperTableViewCell)
        XCTAssertTrue(stepper.titleLabel.text?.contains("30") == true)
        stepper.stepper.value = 60
        stepper.stepperValueChanged(stepper.stepper as Any)
        XCTAssertEqual(interval.integer.value, 60)
        XCTAssertTrue(stepper.titleLabel.text?.contains("60") == true)
        plain.value.value = nil
        view.viewModels = [plain]
        view.tableView.reloadData(); view.view.layoutIfNeeded()
        let missing = try XCTUnwrap(
            view.tableView.cellForRow(at: .init(row: 0, section: 0)) as? DefaultsPlainTableViewCell)
        XCTAssertEqual(missing.valueLabel.text, RuuviLocalization.na)
    }

    func testStepperReuseReconfiguresRangesUnitsAndIntegerEditingAffordances() throws {
        let view = try controller()
        let item = model("Value", type: .stepper)
        item.integer.value = 50
        view.viewModels = [item]
        let host = try AppViewHost(view)
        defer { host.close() }
        let cell = try XCTUnwrap(
            view.tableView(view.tableView, cellForRowAt: .init(row: 0, section: 0)) as? DefaultsStepperTableViewCell)
        for (unit, step): (DefaultsIntegerUnit, Double) in [(.hours, 1), (.minutes, 5), (.seconds, 30), (.decimal, 5)] {
            item.unit = unit
            cell.configure(with: item)
            XCTAssertEqual(cell.stepper.stepValue, step)
            XCTAssertEqual(cell.stepper.maximumValue, 3600)
            XCTAssertTrue(cell.titleLabel.text?.contains("50") == true)
        }
        item.item.value = .imageCompressionQuality
        cell.configure(with: item)
        XCTAssertEqual(cell.stepper.minimumValue, 10)
        XCTAssertEqual(cell.stepper.maximumValue, 100)
        XCTAssertEqual(cell.titleLabel.text, "Value (50%)")
        item.item.value = .graphDownsampleMaximumPoints
        item.integer.value = 2000
        cell.configure(with: item)
        XCTAssertEqual(cell.stepper.minimumValue, 1000)
        XCTAssertEqual(cell.stepper.maximumValue, 5000)
        XCTAssertEqual(cell.stepper.stepValue, 100)
        item.integerEditor = .init(
            range: 1...99, message: "Choose minutes", presets: [], formatValue: { "\($0) minutes" })
        item.integer.value = 10
        cell.configure(with: item)
        XCTAssertEqual(cell.stepper.minimumValue, 1)
        XCTAssertEqual(cell.stepper.maximumValue, 99)
        XCTAssertEqual(cell.stepper.stepValue, 1)
        XCTAssertEqual(cell.accessoryType, .disclosureIndicator)
        XCTAssertEqual(cell.titleLabel.text, "Value (10 minutes)\nTap to edit")
    }

    func testIntegerRowOpensAValidatedEditorAndPlainRowsDoNot() async throws {
        let view = try controller()
        let interval = model("Interval", type: .stepper)
        interval.integer.value = 10
        interval.integerEditor = .init(
            range: 1...99, message: "Choose minutes",
            presets: [.init(title: "Five", value: 5), .init(title: "Invalid", value: 100)], formatValue: { String($0) })
        let plain = model("Info", type: .plain)
        view.viewModels = [interval, plain]
        let host = try AppViewHost(view)
        defer { host.close() }
        view.tableView(view.tableView, didSelectRowAt: .init(row: 1, section: 0))
        XCTAssertNil(view.presentedViewController)
        view.tableView(view.tableView, didSelectRowAt: .init(row: 0, section: 0))
        await waitForAppState("integer editor presented") { view.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(view.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Interval")
        XCTAssertEqual(alert.message, "Choose minutes")
        XCTAssertEqual(alert.actions.map(\.title), ["Five", RuuviLocalization.cancel, RuuviLocalization.ok])
        let field = try XCTUnwrap(alert.textFields?.first)
        let save = try XCTUnwrap(alert.actions.last)
        XCTAssertEqual(field.text, "10")
        for (text, valid) in [("0", false), ("100", false), ("x", false), ("99", true), (" 5 ", true)] {
            field.text = text
            field.sendActions(for: .editingChanged)
            XCTAssertEqual(save.isEnabled, valid, text)
        }
        XCTAssertEqual(interval.integer.value, 10)
    }

    private func controller() throws -> DefaultsTableViewController {
        try XCTUnwrap(
            UIStoryboard(name: "Defaults", bundle: .main)
                .instantiateViewController(withIdentifier: "DefaultsTableViewController")
                as? DefaultsTableViewController)
    }
    private func model(_ title: String, type: DefaultsType) -> DefaultsViewModel {
        let model = DefaultsViewModel(); model.title = title; model.type.value = type; return model
    }
}
