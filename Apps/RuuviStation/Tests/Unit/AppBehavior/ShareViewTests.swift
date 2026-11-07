import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class ShareViewTests: XCTestCase {
    func testSharingUnavailableShowsItsExplanationWithoutAnEmailOrSendButton() throws {
        let fixture = try ShareViewFixture(canShare: false)
        defer { fixture.close() }
        let view = fixture.view
        XCTAssertEqual(view.numberOfSections(in: view.tableView), 1)
        XCTAssertEqual(view.tableView(view.tableView, numberOfRowsInSection: 0), 1)
        let cell = try XCTUnwrap(fixture.cell(section: 0, row: 0) as? ShareDescriptionTableViewCell)
        XCTAssertEqual(cell.sharingDisabledLabel.text, RuuviLocalization.networkSharingDisabled)
        XCTAssertFalse((cell.descriptionLabel.text ?? "").isEmpty)
        XCTAssertFalse(view.tableView.visibleCells.contains { $0 is ShareEmailInputTableViewCell })
        XCTAssertFalse(view.tableView.visibleCells.contains { $0 is ShareSendButtonTableViewCell })
    }

    func testAcceptedAndPendingRecipientsHaveSeparateSectionsAndCanBeUnshared() throws {
        let fixture = try ShareViewFixture(
            canShare: true, accepted: ["active@example.com"], pending: ["pending@example.com"])
        defer { fixture.close() }
        let view = fixture.view
        XCTAssertEqual(view.numberOfSections(in: view.tableView), 5)
        XCTAssertEqual((0..<5).map { view.tableView(view.tableView, numberOfRowsInSection: $0) }, [2, 0, 1, 1, 1])
        let active = try XCTUnwrap(fixture.cell(section: 2, row: 0) as? ShareEmailTableViewCell)
        XCTAssertEqual(active.emailLabel.text, "active@example.com")
        XCTAssertFalse(active.unshareButton.isHidden)
        active.unshareButton.sendActions(for: .touchUpInside)
        let pending = try XCTUnwrap(fixture.cell(section: 3, row: 0) as? ShareEmailTableViewCell)
        XCTAssertEqual(pending.emailLabel.text, "pending@example.com")
        XCTAssertFalse(pending.unshareButton.isHidden)
        pending.unshareButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(fixture.output.unshares.compactMap { $0 }, ["active@example.com", "pending@example.com"])
        let summary = try XCTUnwrap(view.tableView(view.tableView, viewForHeaderInSection: 1))
        XCTAssertEqual(
            summary.allDescendants.compactMap { $0 as? UILabel }.first?.text,
            RuuviLocalization.shareSensorSharedToCountMessage(2, 5, 4, 20))
        XCTAssertNil(view.tableView(view.tableView, viewForHeaderInSection: 4))
        XCTAssertEqual(view.tableView(view.tableView, heightForHeaderInSection: 4), .leastNormalMagnitude)
        XCTAssertEqual(view.tableView(view.tableView, heightForHeaderInSection: 2), UITableView.automaticDimension)
    }

    func testEmailInputTrimsWhitespaceAndClearsAfterSharing() throws {
        let fixture = try ShareViewFixture(canShare: true)
        defer { fixture.close() }
        let input = try XCTUnwrap(fixture.cell(section: 0, row: 0) as? ShareEmailInputTableViewCell)
        input.emailTextField.text = "  friend@example.com  "
        let send = try XCTUnwrap(fixture.cell(section: 0, row: 1) as? ShareSendButtonTableViewCell)
        send.sendButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(fixture.output.emails.compactMap { $0 }, ["friend@example.com"])
        fixture.view.clearInput()
        XCTAssertTrue((input.emailTextField.text ?? "").isEmpty)
        XCTAssertTrue(fixture.view.textFieldShouldReturn(input.emailTextField))
        let empty = try XCTUnwrap(fixture.cell(section: 2, row: 0) as? ShareEmailTableViewCell)
        XCTAssertEqual(empty.emailLabel.text, RuuviLocalization.shareActiveAccessEmptyValue)
        XCTAssertTrue(empty.unshareButton.isHidden)
        XCTAssertFalse(empty.unshareButton.isUserInteractionEnabled)
    }

    func testPendingRecipientsRemainRemovableWhenCellsAreReusedAfterAnEmptyActiveList() throws {
        let fixture = try ShareViewFixture(canShare: true, pending: (0..<40).map { "pending\($0)@example.com" })
        defer { fixture.close() }
        let empty = try XCTUnwrap(fixture.cell(section: 2, row: 0) as? ShareEmailTableViewCell)
        XCTAssertTrue(empty.unshareButton.isHidden)
        _ = try fixture.cell(section: 3, row: 39)
        let pending = fixture.view.tableView.visibleCells.compactMap { $0 as? ShareEmailTableViewCell }
        XCTAssertFalse(pending.isEmpty)
        for cell in pending {
            XCTAssertTrue(cell.emailLabel.text?.hasPrefix("pending") == true)
            XCTAssertFalse(cell.unshareButton.isHidden)
            XCTAssertTrue(cell.unshareButton.isUserInteractionEnabled)
        }
    }
}

@MainActor final class ShareViewFixture {
    let view: ShareViewController
    let output = ShareViewOutputSpy()
    let window: UIWindow
    private let host: AppViewHost
    init(canShare: Bool, accepted: [String] = [], pending: [String] = []) throws {
        view = try XCTUnwrap(
            UIStoryboard(name: "Share", bundle: .main)
                .instantiateViewController(withIdentifier: "ShareViewController") as? ShareViewController)
        view.output = output
        let model = ShareViewModel()
        model.canShare.value = canShare
        model.sharedEmails.value = accepted
        model.pendingSharedEmails.value = pending
        model.maxCount.value = 5
        model.totalUsedCount.value = 4
        model.totalAvailableCount.value = 20
        view.viewModel = model
        host = try AppViewHost(view)
        window = host.window
    }
    func cell(section: Int, row: Int) throws -> UITableViewCell {
        let index = IndexPath(row: row, section: section)
        view.tableView.scrollToRow(at: index, at: .middle, animated: false)
        view.tableView.layoutIfNeeded()
        return try XCTUnwrap(view.tableView.cellForRow(at: index))
    }
    func close() { host.close() }
}

final class ShareViewOutputSpy: ShareViewOutput {
    var loads = 0
    var emails = [String?]()
    var unshares = [String?]()
    func viewDidLoad() { loads += 1 }
    func viewDidTapSendButton(email: String?) { emails.append(email) }
    func viewDidTapUnshareEmail(_ email: String?) { unshares.append(email) }
}
