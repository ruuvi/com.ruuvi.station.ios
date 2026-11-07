import CoreNFC
import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import RuuviDiscover

@MainActor final class DiscoveryDialogContractTests: XCTestCase {
    func testFirmwareConfirmationPreservesTheExactDeviceIdentifierAndCancelDoesNothing() throws {
        let output = DiscoveryDialogOutputSpy()
        let recorder = DiscoveryActionRecorder()
        let view = DiscoveryDialogView()
        view.output = output
        view.alertActionFactory = recorder.make
        view.showUpdateFirmwareDialog(for: "device-123")
        let alert = try XCTUnwrap(view.dialog)
        XCTAssertEqual(alert.title, RuuviLocalization.DiscoverTable.UpdateFirmware.title)
        XCTAssertEqual(alert.message, RuuviLocalization.DiscoverTable.UpdateFirmware.message)
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
        try recorder.invoke(RuuviLocalization.cancel)
        XCTAssertTrue(output.firmwareIDs.isEmpty)
        try recorder.invoke(RuuviLocalization.DiscoverTable.UpdateFirmware.title)
        XCTAssertEqual(output.firmwareIDs, ["device-123"])
    }

    func testSensorDetailsActionsKeepTheNFCIdentityAndOnlyOfferPermittedDestinations() throws {
        let output = DiscoveryDialogOutputSpy()
        let recorder = DiscoveryActionRecorder()
        let view = DiscoveryDialogView()
        view.output = output
        view.alertActionFactory = recorder.make
        let sensor = NFCSensor(id: "secret-123", macId: "AA:BB:CC:DD:EE:FF", firmwareVersion: "3.31.1")
        view.showSensorDetailsDialog(
            for: sensor, message: "Sensor details", showAddSensor: true,
            showGoToSensor: true, showUpgradeFirmware: true, isDF3: false)
        let actions = try XCTUnwrap(view.dialog).actions
        XCTAssertEqual(actions.count, 6)
        for title in [
            RuuviLocalization.addSensor, RuuviLocalization.copyMacAddress, RuuviLocalization.copyUniqueId,
            RuuviLocalization.goToSensor, RuuviLocalization.DFUUIView.navigationTitle,
        ] {
            try recorder.invoke(title)
        }
        XCTAssertEqual(output.events.map(\.0), ["add", "mac", "secret", "goto", "upgrade"])
        XCTAssertTrue(output.events.allSatisfy { $0.1?.id == sensor.id && $0.1?.macId == sensor.macId })
        try recorder.invoke(RuuviLocalization.close)
        XCTAssertEqual(output.events.count, 5)
        recorder.clear()
        view.showSensorDetailsDialog(
            for: nil, message: "Unavailable", showAddSensor: false,
            showGoToSensor: false, showUpgradeFirmware: false, isDF3: true)
        XCTAssertEqual(
            view.dialog?.actions.map(\.title),
            [RuuviLocalization.copyMacAddress, RuuviLocalization.copyUniqueId, RuuviLocalization.close])
        try recorder.invoke(RuuviLocalization.copyMacAddress)
        XCTAssertNil(output.events.last?.1)
        XCTAssertEqual(output.events.last?.0, "mac")
    }

    func testRetainedDialogHandlersDoNotKeepAClosedDiscoveryScreenAlive() throws {
        let output = DiscoveryDialogOutputSpy()
        let recorder = DiscoveryActionRecorder()
        var view: DiscoveryDialogView? = DiscoveryDialogView()
        view?.output = output
        view?.alertActionFactory = recorder.make
        view?.showUpdateFirmwareDialog(for: "old-device")
        weak var released = view
        view = nil
        XCTAssertNil(released)
        try recorder.invoke(RuuviLocalization.DiscoverTable.UpdateFirmware.title)
        XCTAssertTrue(output.firmwareIDs.isEmpty)
    }
}
@MainActor private final class DiscoveryActionRecorder {
    private var entries = [(UIAlertAction, ((UIAlertAction) -> Void)?)]()
    func make(_ title: String?, _ style: UIAlertAction.Style, _ handler: ((UIAlertAction) -> Void)?) -> UIAlertAction {
        let action = UIAlertAction(title: title, style: style, handler: handler)
        entries.append((action, handler))
        return action
    }
    func invoke(_ title: String) throws {
        let entry = try XCTUnwrap(entries.last { $0.0.title == title })
        XCTAssertTrue(entry.0.isEnabled)
        entry.1?(entry.0)
    }
    func clear() { entries.removeAll() }
}
private final class DiscoveryDialogView: DiscoverTableViewController {
    var dialog: UIAlertController?
    override func present(
        _ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil
    ) {
        dialog = viewControllerToPresent as? UIAlertController
        completion?()
    }
}
private final class DiscoveryDialogOutputSpy: DiscoverViewOutput {
    var firmwareIDs = [String]()
    var events = [(String, NFCSensor?)]()
    func viewDidLoad() {}
    func viewWillAppear() {}
    func viewWillDisappear() {}
    func viewDidChoose(device: DiscoverRuuviTagViewModel, displayName: String) {}
    func viewDidTriggerClose() {}
    func viewDidTriggerDisabledBTRow() {}
    func viewDidTriggerBuySensors() {}
    func viewDidTapUseNFC() {}
    func viewDidReceiveNFCMessages(messages: [NFCNDEFMessage]) {}
    func viewDidAddDeviceWithNFC(with sensor: NFCSensor?) { events.append(("add", sensor)) }
    func viewDidGoToSensor(with sensor: NFCSensor?) { events.append(("goto", sensor)) }
    func viewDidACopyMacAddress(of sensor: NFCSensor?) { events.append(("mac", sensor)) }
    func viewDidACopySecret(of sensor: NFCSensor?) { events.append(("secret", sensor)) }
    func viewDidAskToUpgradeFirmware(of sensor: NFCSensor?) { events.append(("upgrade", sensor)) }
    func viewDidConfirmToUpdateFirmware(for uuid: String) { firmwareIDs.append(uuid) }
}
