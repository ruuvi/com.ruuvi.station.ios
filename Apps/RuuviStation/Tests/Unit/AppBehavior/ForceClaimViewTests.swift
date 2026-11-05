import CoreNFC
import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class ForceClaimViewTests: XCTestCase {
    func testIntroBluetoothChoiceAndDeviceSpecificInstructions() async throws {
        let view = SensorForceClaimViewController()
        let output = ForceClaimOutputSpy()
        view.output = output
        let host = try AppViewHost(view)
        defer { host.close() }
        XCTAssertEqual(output.loads, 1)
        await waitForAppState("force claim view appeared") { output.appears > 0 }
        XCTAssertEqual(view.title, RuuviLocalization.forceClaimSensor)
        let buttons = view.view.allDescendants.compactMap { $0 as? UIButton }
        let claim = try XCTUnwrap(buttons.first { $0.title(for: .normal) == RuuviLocalization.forceClaim })
        claim.sendActions(for: .touchUpInside)
        let bluetooth = try XCTUnwrap(buttons.first { $0.title(for: .normal) == RuuviLocalization.useBluetooth })
        XCTAssertEqual(bluetooth.alpha, 1)
        bluetooth.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.bluetooth, 1)
        view.hideNFCButton()
        view.view.layoutIfNeeded()
        let nfc = try XCTUnwrap(buttons.first { $0.title(for: .normal) == RuuviLocalization.useNfc })
        XCTAssertEqual(nfc.alpha, 0)
        XCTAssertEqual(bluetooth.frame.width, 180, accuracy: 1)
        let text = try XCTUnwrap(view.view.allDescendants.compactMap { $0 as? UITextView }.first)
        for type in [RuuviDeviceType.ruuviAir, .ruuviTag] {
            view.deviceType = type
            XCTAssertEqual(
                text.text,
                type == .ruuviAir
                    ? RuuviLocalization.forceClaimAirDescription2 : RuuviLocalization.forceClaimSensorDescription2)
        }
        XCTAssertEqual(text.superview?.alpha, 1)
        XCTAssertFalse(text.isEditable)
    }

    func testWrongSensorAndBluetoothTimeoutDialogsDescribeHowTheClaimFailed() async throws {
        let view = SensorForceClaimViewController()
        let host = try AppViewHost(view)
        defer { host.close() }
        for (message, show) in [
            (RuuviLocalization.claimWrongSensorScanned, view.showWrongTagScanDialog),
            (RuuviLocalization.sensorNotFoundError, view.showGATTConnectionTimeoutDialog),
        ] {
            show()
            await waitForAppState("force claim dialog") { view.presentedViewController is UIAlertController }
            let alert = try XCTUnwrap(view.presentedViewController as? UIAlertController)
            XCTAssertEqual(alert.message, message)
            XCTAssertEqual(alert.actions.map(\.style), [.cancel])
            await withCheckedContinuation { done in view.dismiss(animated: false) { done.resume() } }
        }
    }
}

final class ForceClaimOutputSpy: SensorForceClaimViewOutput {
    var loads = 0
    var appears = 0
    var bluetooth = 0
    var nfc = 0
    func viewDidLoad() { loads += 1 }
    func viewWillAppear() { appears += 1 }
    func viewDidTapUseNFC() { nfc += 1 }
    func viewDidTapUseBluetooth() { bluetooth += 1 }
    func viewDidReceiveNFCMessages(messages: [NFCNDEFMessage]) {}
    func viewDidDismiss() {}
}
