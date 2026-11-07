import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class ShareFeedbackContractTests: XCTestCase {
    func testInvalidAddressAcceptedShareAndPendingInvitationHaveDistinctMessages() async throws {
        let fixture = try ShareViewFixture(canShare: true)
        defer { fixture.close() }
        let cases: [(String?, String, () -> Void)] = [
            (nil, RuuviLocalization.UserApiError.erInvalidEmailAddress, fixture.view.showInvalidEmail),
            (nil, RuuviLocalization.Share.Success.message, fixture.view.showSuccessfullyShared),
            (
                RuuviLocalization.sharePending, RuuviLocalization.sharePendingMessage,
                fixture.view.showSuccessfullyInvited
            ),
        ]
        for (title, message, show) in cases {
            show()
            await waitForAppState("sharing feedback visible") {
                fixture.view.presentedViewController is UIAlertController
                    && fixture.view.presentedViewController?.isBeingPresented == false
            }
            let alert = try XCTUnwrap(fixture.view.presentedViewController as? UIAlertController)
            XCTAssertEqual(alert.title, title)
            XCTAssertEqual(alert.message, message)
            XCTAssertEqual(alert.actions.count, 1)
            XCTAssertEqual(alert.actions.first?.title, RuuviLocalization.ok)
            await withCheckedContinuation { done in fixture.view.dismiss(animated: false) { done.resume() } }
        }
        XCTAssertTrue(fixture.output.emails.isEmpty)
        XCTAssertTrue(fixture.output.unshares.isEmpty)
    }

    func testEditingEmailScrollsTheExplanationIntoViewAndReloadPreservesRecipients() async throws {
        let fixture = try ShareViewFixture(canShare: true, accepted: (0..<20).map { "person\($0)@example.com" })
        defer { fixture.close() }
        let input = try XCTUnwrap(fixture.cell(section: 0, row: 0) as? ShareEmailInputTableViewCell)
        fixture.view.textFieldDidBeginEditing(input.emailTextField)
        let last = IndexPath(row: 0, section: fixture.view.tableView.numberOfSections - 1)
        await waitForAppState("sharing description scrolled into view") {
            fixture.view.tableView.indexPathsForVisibleRows?.contains(last) == true
        }
        fixture.view.reloadTableView()
        XCTAssertEqual(fixture.view.tableView.numberOfRows(inSection: 2), 20)
        XCTAssertEqual(fixture.view.viewModel.sharedEmails.value?.first, "person0@example.com")
        XCTAssertTrue(fixture.output.unshares.isEmpty)
    }
}
