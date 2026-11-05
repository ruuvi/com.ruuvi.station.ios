import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class OnboardingAndRemovalViewTests: XCTestCase {
    func testSignInBenefitsExplainTheOptionalAccountAndForwardContinueAndClose() throws {
        let view = SignInBenefitsViewController()
        let output = BenefitsOutputSpy()
        view.output = output
        let host = try AppViewHost(view)
        defer { host.close() }
        let labels = descendants(view.view).compactMap { ($0 as? UILabel)?.text }
        XCTAssertTrue(labels.contains(RuuviLocalization.whyShouldSignIn))
        XCTAssertTrue(labels.contains(RuuviLocalization.signingInIsOptional))
        XCTAssertTrue(labels.contains(RuuviLocalization.sensorsOwnershipAndSettingsStoredInCloud))
        let button = try XCTUnwrap(descendants(view.view).compactMap { $0 as? UIButton }.first {
            $0.title(for: .normal) == RuuviLocalization.signInContinue
        })
        XCTAssertGreaterThan(button.frame.width, 0)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.continues, 1)
        let close = try XCTUnwrap(view.navigationItem.leftBarButtonItem)
        _ = (close.target as? NSObject)?.perform(try XCTUnwrap(close.action), with: close)
        XCTAssertEqual(output.closes, 1)
    }

    func testRemovalExplainsEachOwnershipModeAndForwardsTheRequestWithoutRemovingAnything() throws {
        let view = SensorRemovalViewController()
        let output = RemovalViewOutputSpy()
        view.output = output
        let host = try AppViewHost(view)
        defer { host.close() }
        XCTAssertEqual(output.loads, 1)
        let rows: [(SensorOwnership, String, Bool)] = [
            (.claimedByMe, RuuviLocalization.removeClaimedSensorDescription, true),
            (.sharedWithMe, RuuviLocalization.removeSharedSensorDescription, false),
            (.locallyAddedButNotMine, RuuviLocalization.removeLocalSensorDescription, false),
            (.locallyAddedAndNotClaimed, RuuviLocalization.removeLocalSensorDescription, false),
        ]
        for (ownership, message, showsHistory) in rows {
            view.updateView(ownership: ownership)
            view.view.layoutIfNeeded()
            XCTAssertTrue(descendants(view.view).compactMap { ($0 as? UILabel)?.text }.contains(message))
            XCTAssertEqual(view.removeButtonConstraintClaimedSensor.isActive, showsHistory)
            XCTAssertEqual(view.removeButtonConstraintOtherSensor.isActive, !showsHistory)
            XCTAssertEqual(view.children.first?.view.superview?.isHidden, !showsHistory)
        }
        let remove = try XCTUnwrap(descendants(view.view).compactMap { $0 as? UIButton }.first {
            $0.title(for: .normal) == RuuviLocalization.remove
        })
        remove.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.requests, 1)
        XCTAssertTrue(output.confirmed.isEmpty)
    }

    func testRemovingCloudHistoryRequiresAnExplicitDestructiveConfirmation() async throws {
        let view = SensorRemovalViewController()
        let output = RemovalViewOutputSpy()
        view.output = output
        let host = try AppViewHost(view)
        defer { host.close() }
        view.updateView(ownership: .claimedByMe)
        view.showHistoryDataRemovalConfirmationDialog()
        await waitForAppState("history removal confirmation") { view.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(view.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, RuuviLocalization.dialogAreYouSure)
        XCTAssertEqual(alert.message, RuuviLocalization.dialogOperationUndone)
        XCTAssertEqual(alert.actions.map(\.style), [.destructive, .cancel])
        XCTAssertTrue(output.confirmed.isEmpty)
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
}

private final class BenefitsOutputSpy: SignInBenefitsViewOutput {
    var continues = 0
    var closes = 0
    func viewDidLoad() {}
    func viewDidTapContinue() { continues += 1 }
    func viewDidTapClose() { closes += 1 }
}

private final class RemovalViewOutputSpy: SensorRemovalViewOutput {
    var loads = 0
    var requests = 0
    var confirmed = [Bool]()
    func viewDidLoad() { loads += 1 }
    func viewDidTriggerRemoveTag() { requests += 1 }
    func viewDidConfirmTagRemoval(with removeCloudData: Bool) { confirmed.append(removeCloudData) }
    func viewDidDismiss() {}
}
