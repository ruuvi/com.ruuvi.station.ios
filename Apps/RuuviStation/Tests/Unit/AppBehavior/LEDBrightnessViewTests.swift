import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class LEDBrightnessViewTests: XCTestCase {
    func testUnsupportedFirmwareOffersAnUpdateAndSupportedFirmwareShowsEveryBrightnessLevel() throws {
        for version: String? in [nil, "invalid", "1.2.9", "1.3.0", "2.0.0"] {
            let fixture = try LEDBrightnessFixture(version: version)
            defer { fixture.host.close() }
            let supported = version == "1.3.0" || version == "2.0.0"
            XCTAssertEqual(fixture.view.title, RuuviLocalization.ledBrightnessControl)
            XCTAssertEqual(fixture.table.isHidden, !supported)
            XCTAssertEqual(fixture.table.numberOfRows(inSection: 0), supported ? 4 : 0)
            let update = try XCTUnwrap(
                fixture.view.view.allDescendants.compactMap { $0 as? UIButton }.first {
                    $0.title(for: .normal) == RuuviLocalization.updateNow
                })
            XCTAssertEqual(update.isHidden, supported)
            var updates = 0
            fixture.view.onUpdateFirmware = { updates += 1 }
            if supported {
                for (index, level) in RuuviLedBrightnessLevel.allCases.enumerated() {
                    let cell = try XCTUnwrap(fixture.table.cellForRow(at: IndexPath(row: index, section: 0)))
                    XCTAssertEqual(cell.allDescendants.compactMap { $0 as? UILabel }.first?.text, level.title)
                    XCTAssertEqual(cell.accessoryType, level == .normal ? .checkmark : .none)
                }
            } else {
                update.sendActions(for: .touchUpInside)
                XCTAssertEqual(updates, 1)
            }
        }
    }

    func testBrightnessChangesAreSerializedUntilTheDeviceAcknowledgesThem() async throws {
        let fixture = try LEDBrightnessFixture(version: "1.3.0")
        defer { fixture.host.close() }
        var values = [RuuviLedBrightnessLevel]()
        var completion: ((Result<Void, Error>) -> Void)?
        fixture.view.onSelection = { value, done in
            values.append(value); completion = done
        }
        fixture.view.tableView(fixture.table, didSelectRowAt: IndexPath(row: 0, section: 0))
        fixture.view.tableView(fixture.table, didSelectRowAt: IndexPath(row: 3, section: 0))
        XCTAssertEqual(values, [.off])
        completion?(.success(()))
        await flushAppBindings()
        fixture.view.tableView(fixture.table, didSelectRowAt: IndexPath(row: 3, section: 0))
        XCTAssertEqual(values, [.off, .bright])
        completion?(.success(()))
        await flushAppBindings()
        fixture.table.layoutIfNeeded()
        XCTAssertEqual(fixture.table.cellForRow(at: IndexPath(row: 3, section: 0))?.accessoryType, .checkmark)
    }

    func testFailedDeviceWriteRestoresPreviousSelectionAndShowsAnError() async throws {
        let fixture = try LEDBrightnessFixture(version: "1.3.0")
        defer { fixture.host.close() }
        fixture.view.onSelection = { _, done in
            done(
                .failure(
                    NSError(
                        domain: "LEDTests", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "The sensor disconnected"])))
        }
        fixture.view.tableView(fixture.table, didSelectRowAt: IndexPath(row: 0, section: 0))
        await waitForAppState("brightness write error") { fixture.view.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(fixture.view.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.message, "The sensor disconnected")
        fixture.table.layoutIfNeeded()
        XCTAssertEqual(fixture.table.cellForRow(at: IndexPath(row: 2, section: 0))?.accessoryType, .checkmark)
        XCTAssertEqual(fixture.table.cellForRow(at: IndexPath(row: 0, section: 0))?.accessoryType, UITableViewCell.AccessoryType.none)
    }

    func testFirmwareEventsOnlyUpdateTheMatchingSensor() throws {
        let services = CoordinatorFixture()
        defer { services.cleanup() }
        let snapshot = services.data.measurements.snapshot
        let fixture = try LEDBrightnessFixture(version: "1.2.9", snapshotID: snapshot.id)
        defer { fixture.host.close() }
        let other = MeasurementFixture().snapshot
        other.displayData.firmwareVersion = "2.0.0"
        fixture.view.coordinatorDidReceiveEvent(
            services.coordinator, event: .snapshotUpdated(other, invalidateLayout: false))
        XCTAssertTrue(fixture.table.isHidden)
        snapshot.displayData.firmwareVersion = "1.3.0"
        fixture.view.coordinatorDidReceiveEvent(
            services.coordinator, event: .snapshotsUpdated([other, snapshot], reason: .initial, withAnimation: false))
        XCTAssertFalse(fixture.table.isHidden)
        XCTAssertEqual(fixture.table.numberOfRows(inSection: 0), 4)
        fixture.view.coordinatorDidReceiveEvent(services.coordinator, event: .alertSnapshotUpdated(snapshot))
        snapshot.displayData.firmwareVersion = nil
        fixture.view.coordinatorDidReceiveEvent(services.coordinator, event: .connectionSnapshotUpdated(snapshot))
        XCTAssertTrue(fixture.table.isHidden)
        fixture.view.coordinatorDidReceiveEvent(services.coordinator, event: .cloudSyncCompleted)
        XCTAssertTrue(fixture.table.isHidden)
    }
}

@MainActor final class LEDBrightnessFixture {
    let view: LEDBrightnessSettingsViewController
    let host: AppViewHost
    let table: UITableView
    init(version: String?, snapshotID: String? = nil) throws {
        view = LEDBrightnessSettingsViewController(selection: .normal, firmwareVersion: version, snapshotId: snapshotID)
        host = try AppViewHost(view)
        table = try XCTUnwrap(view.view.allDescendants.compactMap { $0 as? UITableView }.first)
        table.layoutIfNeeded()
    }
}
