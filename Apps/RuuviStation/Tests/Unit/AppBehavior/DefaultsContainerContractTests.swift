import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class DefaultsContainerContractTests: XCTestCase {
    func testContainerEmbedsTheConfiguredRowsAndUpdatesTheVisibleTable() async throws {
        let controller = try XCTUnwrap(
            UIStoryboard(name: "Defaults", bundle: .main)
                .instantiateViewController(withIdentifier: "DefaultsViewController") as? DefaultsViewController)
        let output = DefaultsContainerOutputSpy()
        controller.output = output
        let row = DefaultsViewModel()
        row.type.value = .plain
        row.title = "Configuration version"
        row.value.value = "42"
        controller.viewModels = [row]
        let host = try AppViewHost(controller)
        defer { host.close() }
        XCTAssertEqual(controller.navigationItem.title, RuuviLocalization.Defaults.NavigationItem.title)
        XCTAssertFalse(controller.tableContainer.isHidden)
        XCTAssertTrue(controller.listContainer.isHidden)
        let table = try XCTUnwrap(controller.children.compactMap { $0 as? DefaultsTableViewController }.first)
        XCTAssertTrue(table.output as? DefaultsContainerOutputSpy === output)
        XCTAssertTrue(table.viewModels.first === row)
        table.tableView.layoutIfNeeded()
        let cell = try XCTUnwrap(
            table.tableView.cellForRow(at: .init(row: 0, section: 0)) as? DefaultsPlainTableViewCell)
        XCTAssertEqual(cell.titleLabel.text, "Configuration version")
        XCTAssertEqual(cell.valueLabel.text, "42")
        controller.viewModels = []
        XCTAssertTrue(table.viewModels.isEmpty)
        XCTAssertEqual(table.tableView.numberOfRows(inSection: 0), 0)
        XCTAssertTrue(output.endpointChanges.isEmpty)
    }

    func testChangingTheEndpointFirstPresentsExplicitSignOutConfirmation() throws {
        let controller = try XCTUnwrap(
            UIStoryboard(name: "Defaults", bundle: .main)
                .instantiateViewController(withIdentifier: "DefaultsViewController") as? DefaultsViewController)
        let output = DefaultsContainerOutputSpy()
        controller.output = output
        let host = try AppViewHost(controller)
        defer { host.close() }
        controller.showEndpointChangeConfirmationDialog(useDevServer: true)
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.message, RuuviLocalization.Defaults.DevServer.message)
        XCTAssertEqual(alert.actions.map(\.title), [RuuviLocalization.cancel, RuuviLocalization.Menu.SignOut.text])
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
        XCTAssertTrue(output.endpointChanges.isEmpty)
    }
}
private final class DefaultsContainerOutputSpy: DefaultsViewOutput {
    var endpointChanges = [Bool?]()
    func viewDidTriggerUseDevServer(useDevServer: Bool?) { endpointChanges.append(useDevServer) }
}
