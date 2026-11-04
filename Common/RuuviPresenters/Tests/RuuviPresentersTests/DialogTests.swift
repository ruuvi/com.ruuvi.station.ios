import UIKit
import XCTest
@testable import RuuviPresenters

@MainActor final class DialogTests: XCTestCase {
    func testDialogDisplaysContentAndForwardsBothActions() throws {
        let controller = RuuviDialogViewController(
            configuration: .init(
                title: "Confirm sensor removal", message: "History will be removed from this phone.",
                image: UIImage(systemName: "sensor.tag.radiowaves.forward"), primaryActionTitle: "Remove",
                secondaryActionTitle: "Cancel"))
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        controller.view.layoutIfNeeded()
        let labels = descendants(of: controller.view, as: UILabel.self)
        XCTAssertTrue(
            labels.contains { $0.text == "Confirm sensor removal" && $0.accessibilityTraits.contains(.header) })
        XCTAssertTrue(labels.contains { $0.text == "History will be removed from this phone." })
        XCTAssertTrue(controller.view.accessibilityViewIsModal)
        XCTAssertTrue(controller.isModalInPresentation)
        XCTAssertEqual(controller.modalPresentationStyle, .overFullScreen)
        let buttons = descendants(of: controller.view, as: UIButton.self)
        let primary = try XCTUnwrap(buttons.first { $0.title(for: .normal) == "Remove" })
        let secondary = try XCTUnwrap(buttons.first { $0.title(for: .normal) == "Cancel" })
        var actions: [String] = []
        controller.onPrimaryAction = { actions.append("remove") }
        controller.onSecondaryAction = { actions.append("cancel") }
        try activate(primary)
        try activate(secondary)
        XCTAssertEqual(actions, ["remove", "cancel"])
    }

    func testLoadingDisablesBothButtonsAndErrorCanBeClearedWhenReconfigured() throws {
        let controller = RuuviDialogViewController(
            configuration: .init(
                title: "Delete", primaryActionTitle: "Confirm", secondaryActionTitle: "Cancel"))
        controller.loadViewIfNeeded()
        let buttons = descendants(of: controller.view, as: UIButton.self)
        let spinner = try XCTUnwrap(descendants(of: controller.view, as: UIActivityIndicatorView.self).first)
        controller.setLoading(true)
        XCTAssertTrue(buttons.allSatisfy { !$0.isEnabled })
        XCTAssertTrue(spinner.isAnimating)
        controller.showError("Try again")
        XCTAssertTrue(
            descendants(of: controller.view, as: UILabel.self).contains { $0.text == "Try again" && !$0.isHidden })
        controller.setLoading(false)
        XCTAssertTrue(buttons.allSatisfy(\.isEnabled))
        XCTAssertFalse(spinner.isAnimating)
        controller.configure(.init(title: "Updated", primaryActionTitle: "Done"))
        XCTAssertFalse(
            descendants(of: controller.view, as: UILabel.self).contains { $0.text == "Try again" && !$0.isHidden })
        XCTAssertTrue(buttons.contains { $0.isHidden })
    }

    func testLongContentGrowsAndScrollsWithinSmallScreen() throws {
        let short = RuuviDialogView(configuration: .init(title: "Title", primaryActionTitle: "Done"))
        let message = String(repeating: "Long translated instructions must remain readable. ", count: 30)
        let controller = RuuviDialogViewController(
            configuration: .init(
                title: "Title", message: message, primaryActionTitle: "Done"))
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        controller.view.layoutIfNeeded()
        let dialog = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? RuuviDialogView }.first)
        XCTAssertGreaterThan(dialog.preferredHeight(for: 272), short.preferredHeight(for: 272))
        XCTAssertLessThanOrEqual(dialog.frame.height, 448)
        let scroll = try XCTUnwrap(descendants(of: dialog, as: UIScrollView.self).first)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        XCTAssertFalse(dialog.hasAmbiguousLayout)
    }

    func testAppearanceAndDismissCallbacksAreDelivered() {
        let controller = RuuviDialogViewController(configuration: .init(title: "Title", primaryActionTitle: "Done"))
        controller.loadViewIfNeeded()
        var appeared = 0
        var dismissed = 0
        controller.onDidAppear = { appeared += 1 }
        controller.onDismiss = { dismissed += 1 }
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()
        XCTAssertEqual(appeared, 1)
        XCTAssertEqual(dismissed, 1)
    }

    private func activate(_ button: UIButton) throws {
        let target = try XCTUnwrap(button.allTargets.first as? NSObject)
        let action = try XCTUnwrap(button.actions(forTarget: target, forControlEvent: .touchUpInside)?.first)
        XCTAssertTrue(target.responds(to: NSSelectorFromString(action)))
        target.perform(NSSelectorFromString(action))
    }

    private func descendants<T: UIView>(of view: UIView, as type: T.Type) -> [T] {
        view.subviews.flatMap { child in
            ((child as? T).map { [$0] } ?? []) + descendants(of: child, as: type)
        }
    }
}
