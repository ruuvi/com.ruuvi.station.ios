import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class OwnerViewTests: XCTestCase {
    func testClaimAndUnclaimModesShowTheRightInstructionsAndForwardTheOwnershipAction() throws {
        for mode: OwnershipMode in [.claim, .unclaim] {
            let view = try makeView()
            let output = OwnerViewOutputSpy()
            view.output = output
            view.mode = mode
            let host = try AppViewHost(view)
            defer { host.close() }
            XCTAssertEqual(output.firmwarePrompts, 1)
            XCTAssertEqual(view.title, mode == .claim ? RuuviLocalization.Owner.title : RuuviLocalization.unclaimSensor)
            XCTAssertEqual(view.removeCloudHistoryActionContainer.isHidden, mode == .claim)
            XCTAssertEqual(view.removeCloudHistoryContainerVisibleConstraint.isActive, mode == .unclaim)
            XCTAssertEqual(view.removeCloudHistoryContainerHiddenConstraint.isActive, mode == .claim)
            XCTAssertFalse((view.claimOwnershipDescriptionLabel.text ?? "").isEmpty)
            view.claimOwnershipButton.sendActions(for: .touchUpInside)
            XCTAssertEqual(output.claims, [mode])
            XCTAssertGreaterThan(view.claimOwnershipButton.frame.width, 0)
        }
    }

    func testOwnershipAndFirmwareDialogsPresentTheirExpectedChoices() async throws {
        let view = try makeView()
        let output = OwnerViewOutputSpy()
        view.output = output
        let host = try AppViewHost(view)
        defer { host.close() }
        let dialogs: [(String, [UIAlertAction.Style], () -> Void)] = [
            (
                RuuviLocalization.UserApiError.erSensorAlreadyClaimedNoEmail, [.default],
                view.showSensorAlreadyClaimedDialog
            ),
            (
                RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message, [.cancel, .default],
                view.showFirmwareUpdateDialog
            ),
            (
                RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message, [.cancel, .default],
                view.showFirmwareDismissConfirmationUpdateDialog
            ),
            (
                RuuviLocalization.dialogOperationUndone, [.destructive, .cancel],
                view.showUnclaimHistoryDataRemovalConfirmationDialog
            ),
        ]
        for (message, styles, show) in dialogs {
            show()
            await waitForAppState("ownership dialog") { view.presentedViewController is UIAlertController }
            let alert = try XCTUnwrap(view.presentedViewController as? UIAlertController)
            XCTAssertEqual(alert.message, message)
            XCTAssertEqual(alert.actions.map(\.style), styles)
            await withCheckedContinuation { done in view.dismiss(animated: false) { done.resume() } }
        }
    }

    private func makeView() throws -> OwnerViewController {
        try XCTUnwrap(
            UIStoryboard(name: "Owner", bundle: .main)
                .instantiateInitialViewController() as? OwnerViewController)
    }
}

final class OwnerViewOutputSpy: OwnerViewOutput {
    var claims = [OwnershipMode]()
    var firmwarePrompts = 0
    func viewDidTapOnClaim(mode: OwnershipMode) { claims.append(mode) }
    func viewDidConfirmUnclaim(removeCloudHistory: Bool) {}
    func updateOwnerInfo(with email: String) {}
    func viewDidTriggerFirmwareUpdateDialog() { firmwarePrompts += 1 }
    func viewDidConfirmFirmwareUpdate() {}
    func viewDidIgnoreFirmwareUpdateDialog() {}
    func viewDidDismiss() {}
}
