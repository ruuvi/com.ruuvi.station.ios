import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import RuuviDiscover
@testable import station

@MainActor final class DiscoveryScreenTests: XCTestCase {
    func testNfcDetailsPresentOnlyTheActionsThatAreValidForTheSensor() async throws {
        let fixture = DiscoveryFixture()
        let view = DiscoverTableViewController()
        view.output = fixture.presenter
        let host = try AppViewHost(view)
        defer { host.close(); fixture.cleanup() }
        let tag = NFCSensor(id: "secret", macId: "AA:BB:CC:DD:EE:FF", firmwareVersion: "3.31.1")
        for mode in 0..<4 {
            view.showSensorDetailsDialog(
                for: tag, message: "Office sensor details", showAddSensor: mode == 0,
                showGoToSensor: mode == 1, showUpgradeFirmware: mode == 2, isDF3: mode == 2)
            await waitForAppState("NFC details presented") { view.presentedViewController is UIAlertController }
            let alert = try XCTUnwrap(view.presentedViewController as? UIAlertController)
            XCTAssertEqual(alert.title, RuuviLocalization.sensorDetails)
            let titles = alert.actions.compactMap(\.title)
            XCTAssertEqual(titles.contains(RuuviLocalization.addSensor), mode == 0)
            XCTAssertEqual(titles.contains(RuuviLocalization.goToSensor), mode == 1)
            XCTAssertEqual(titles.contains(RuuviLocalization.DFUUIView.navigationTitle), mode == 2)
            XCTAssertTrue(titles.contains(RuuviLocalization.copyMacAddress))
            XCTAssertTrue(titles.contains(RuuviLocalization.copyUniqueId))
            XCTAssertEqual(alert.actions.last?.style, .cancel)
            await withCheckedContinuation { continuation in
                view.dismiss(animated: false) { continuation.resume() }
            }
        }
        XCTAssertTrue(fixture.ownership.additions.isEmpty)
    }

    func testUpgradeAndBluetoothPromptsExplainWhyTheSensorCannotBeAdded() async throws {
        let fixture = DiscoveryFixture()
        let view = DiscoverTableViewController()
        view.output = fixture.presenter
        let host = try AppViewHost(view)
        defer { host.close(); fixture.cleanup() }
        view.showUpdateFirmwareDialog(for: UUID().uuidString)
        await waitForAppState("firmware requirement prompt") { view.presentedViewController is UIAlertController }
        var alert = try XCTUnwrap(view.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.message, RuuviLocalization.DiscoverTable.UpdateFirmware.message)
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
        await withCheckedContinuation { continuation in view.dismiss(animated: false) { continuation.resume() } }
        view.showBluetoothDisabled(userDeclined: true)
        await waitForAppState("Bluetooth requirement prompt") { view.presentedViewController is UIAlertController }
        alert = try XCTUnwrap(view.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.message, RuuviLocalization.DiscoverTable.BluetoothDisabledAlert.message)
        XCTAssertEqual(alert.actions.map(\.style), [.default, .cancel])
    }
}
