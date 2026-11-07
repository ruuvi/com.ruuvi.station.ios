import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class DashboardSearchInteractionTests: XCTestCase {
    func testOpeningSearchAndCancellingPendingInputRestoresAllSensorsAndToolbar() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let host = try XCTUnwrap(fixture.host)
        let originalTitle = fixture.view.navigationItem.titleView
        let originalLeft = fixture.view.navigationItem.leftBarButtonItem
        let originalRight = fixture.view.navigationItem.rightBarButtonItem
        let search = try XCTUnwrap(
            host.window.allDescendants.first { $0.accessibilityIdentifier == "dashboard.search" })
        XCTAssertTrue(search.isAccessibilityElement)
        XCTAssertTrue(search.gestureRecognizers?.contains { $0 is UITapGestureRecognizer } == true)
        let field = try await fixture.openSearch()
        await waitForAppState("search becomes editable") { field.isFirstResponder }
        XCTAssertFalse(field.isHidden)
        field.text = "Kitchen"
        field.sendActions(for: .editingChanged)
        let cancel = try button("handleSearchCancelTap", in: host.window, target: fixture.view)
        cancel.sendActions(for: .touchUpInside)
        await waitForAppState("toolbar restored after cancelling") {
            !field.isFirstResponder && fixture.collection.numberOfItems(inSection: 0) == 3
        }
        // Wait beyond the original debounce deadline to prove it cannot replace the restored list.
        let settled = expectation(description: "cancelled search deadline elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        await fulfillment(of: [settled], timeout: 2)
        XCTAssertEqual(fixture.collection.numberOfItems(inSection: 0), 3)
        XCTAssertEqual(field.text, "")
        if #unavailable(iOS 26) {
            XCTAssertTrue(fixture.view.navigationItem.titleView === originalTitle)
            XCTAssertTrue(fixture.view.navigationItem.leftBarButtonItem === originalLeft)
            XCTAssertTrue(fixture.view.navigationItem.rightBarButtonItem === originalRight)
        } else {
            XCTAssertEqual(search.alpha, 1)
        }
        _ = fixture.view.perform(NSSelectorFromString("handleMenuButtonTap"))
        XCTAssertEqual(fixture.output.navigation.last?.0, "menu")
        let reopened = try await fixture.openSearch()
        XCTAssertTrue(reopened === field)
        await waitForAppState("search reopened") { field.isFirstResponder }
        field.text = "OUTSIDE"
        field.sendActions(for: .editingChanged)
        await waitForAppState("reopened search selects correct result") {
            fixture.collection.numberOfItems(inSection: 0) == 1
        }
        fixture.view.collectionView(fixture.collection, didSelectItemAt: IndexPath(item: 0, section: 0))
        XCTAssertEqual(fixture.output.navigation.last?.1, fixture.snapshots[2].id)
    }

    private func button(_ selector: String, in root: UIView, target: AnyObject) throws -> UIButton {
        try XCTUnwrap(
            root.allDescendants.compactMap { $0 as? UIButton }.first {
                ($0.actions(forTarget: target, forControlEvent: .touchUpInside) ?? []).contains(selector)
            }, "Missing control for " + selector)
    }
}
