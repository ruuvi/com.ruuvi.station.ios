import CoreNFC
import UIKit
import XCTest
import RuuviOntology
@testable import RuuviDiscover

@MainActor final class RuuviDiscoverTests: XCTestCase {
    func testEmptyDiscoveryAndDisabledBluetoothUseDistinctMessagesAndActions() throws {
        let output = DiscoverOutputSpy()
        let view = makeView(output: output)
        let table = try XCTUnwrap(view.view.subviews.compactMap { $0 as? UITableView }.first)
        XCTAssertEqual(output.loaded, 1)
        XCTAssertEqual(view.tableView(table, numberOfRowsInSection: 0), 1)
        let index = IndexPath(row: 0, section: 0)
        let enabled = try XCTUnwrap(view.tableView(table, cellForRowAt: index) as? DiscoverNoDevicesTableViewCell)
        let enabledMessage = enabled.descriptionLabel.text
        view.tableView(table, didSelectRowAt: index)
        XCTAssertEqual(output.disabledTaps, 0)
        view.isBluetoothEnabled = false
        let disabled = try XCTUnwrap(view.tableView(table, cellForRowAt: index) as? DiscoverNoDevicesTableViewCell)
        XCTAssertNotEqual(disabled.descriptionLabel.text, enabledMessage)
        view.tableView(table, didSelectRowAt: index)
        XCTAssertEqual(output.disabledTaps, 1)
    }

    func testSignalStrengthAndUnknownSignalRenderWithoutLosingDeviceIdentity() throws {
        let output = DiscoverOutputSpy()
        let view = makeView(output: output)
        let table = try XCTUnwrap(view.view.subviews.compactMap { $0 as? UITableView }.first)
        view.ruuviTags = [-90, -65, -30, nil].enumerated().map { index, rssi in
            DiscoverRuuviTagViewModel(
                luid: UUID().uuidString.luid.any, isConnectable: true,
                rssi: rssi, mac: "AA:BB:CC:DD:EE:0\(index)", name: "Sensor \(index)", dataFormat: 5)
        }
        XCTAssertEqual(view.tableView(table, numberOfRowsInSection: 0), 4)
        for index in 0..<4 {
            let path = IndexPath(row: index, section: 0)
            let cell = try XCTUnwrap(view.tableView(table, cellForRowAt: path) as? DiscoverDeviceTableViewCell)
            XCTAssertEqual(cell.identifierLabel.text, "RuuviTag EE0\(index)")
            if index == 3 {
                XCTAssertNil(cell.rssiLabel.text)
                XCTAssertNil(cell.rssiImageView.image)
            } else {
                XCTAssertNotNil(cell.rssiLabel.text)
                XCTAssertNotNil(cell.rssiImageView.image)
            }
            view.tableView(table, didSelectRowAt: path)
            XCTAssertEqual(output.selectedMAC, view.ruuviTags[index].mac)
            XCTAssertEqual(output.selectedName, "RuuviTag EE0\(index)")
        }
    }

    func testLifecycleAndCloseButtonForwardToOutput() throws {
        let output = DiscoverOutputSpy()
        let view = makeView(output: output)
        view.beginAppearanceTransition(true, animated: false)
        view.endAppearanceTransition()
        view.beginAppearanceTransition(false, animated: false)
        view.endAppearanceTransition()
        XCTAssertEqual(output.appeared, 1)
        XCTAssertEqual(output.disappeared, 1)
        view.isCloseEnabled = false
        XCTAssertNil(view.navigationItem.leftBarButtonItem)
        view.isCloseEnabled = true
        let button = try XCTUnwrap(view.navigationItem.leftBarButtonItem)
        let target = try XCTUnwrap(button.target as? NSObject)
        XCTAssertTrue(target === view)
        target.perform(try XCTUnwrap(button.action))
        XCTAssertEqual(output.closed, 1)
    }

    private func makeView(output: DiscoverOutputSpy) -> DiscoverTableViewController {
        let view = DiscoverTableViewController()
        view.output = output
        view.loadViewIfNeeded()
        view.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        view.view.layoutIfNeeded()
        return view
    }
}

private final class DiscoverOutputSpy: DiscoverViewOutput {
    var loaded = 0
    var appeared = 0
    var disappeared = 0
    var closed = 0
    var disabledTaps = 0
    var selectedMAC: String?
    var selectedName: String?
    func viewDidLoad() { loaded += 1 }
    func viewWillAppear() { appeared += 1 }
    func viewWillDisappear() { disappeared += 1 }
    func viewDidChoose(device: DiscoverRuuviTagViewModel, displayName: String) {
        selectedMAC = device.mac; selectedName = displayName
    }
    func viewDidTriggerClose() { closed += 1 }
    func viewDidTriggerDisabledBTRow() { disabledTaps += 1 }
    func viewDidTriggerBuySensors() {}
    func viewDidTapUseNFC() {}
    func viewDidReceiveNFCMessages(messages: [NFCNDEFMessage]) {}
    func viewDidAddDeviceWithNFC(with sensor: NFCSensor?) {}
    func viewDidGoToSensor(with sensor: NFCSensor?) {}
    func viewDidACopyMacAddress(of sensor: NFCSensor?) {}
    func viewDidACopySecret(of sensor: NFCSensor?) {}
    func viewDidAskToUpgradeFirmware(of sensor: NFCSensor?) {}
    func viewDidConfirmToUpdateFirmware(for uuid: String) {}
}
