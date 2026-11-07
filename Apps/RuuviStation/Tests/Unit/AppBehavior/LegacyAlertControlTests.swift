import UIKit
import XCTest
@testable import station

@MainActor final class LegacyAlertControlTests: XCTestCase {
    func testEditableDescriptionPreservesPlainAndAttributedTextAndRoutesTapsToItsOwner() throws {
        let view = RUAlertDetailsCellChildView(frame: CGRect(x: 0, y: 0, width: 320, height: 60))
        let delegate = LegacyAlertControlDelegate()
        view.delegate = delegate
        view.configure(with: "Kitchen 🌿")
        XCTAssertEqual(view.titleLabel.text, "Kitchen 🌿")
        XCTAssertEqual(view.titleLabel.numberOfLines, 0)
        view.layoutIfNeeded()
        let icon = try XCTUnwrap(view.allDescendants.compactMap { $0 as? UIImageView }.first)
        XCTAssertNotNil(icon.image)
        XCTAssertEqual(icon.bounds.size, CGSize(width: 16, height: 16))
        let message = NSMutableAttributedString(string: "High temperature", attributes: [.foregroundColor: UIColor.red])
        view.configure(with: message)
        XCTAssertEqual(view.titleLabel.attributedText, message)
        XCTAssertTrue(view.isUserInteractionEnabled)
        XCTAssertTrue(view.gestureRecognizers?.contains { $0 is UITapGestureRecognizer } == true)
        view.perform(NSSelectorFromString("handleViewTap"))
        XCTAssertTrue(delegate.descriptionTaps.first === view)
        view.configure(with: nil as String?)
        XCTAssertNil(view.titleLabel.text)
        view.configure(with: nil as NSMutableAttributedString?)
        XCTAssertNil(view.titleLabel.attributedText)
    }

    func testExpansionAlternatesTheChevronAndReportsEachDecisionExactlyOnce() {
        let view = RUAlertExpandButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        let delegate = LegacyAlertControlDelegate()
        view.delegate = delegate
        let animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animations) }
        view.toggle()
        XCTAssertEqual(delegate.expansions.map(\.1), [true])
        XCTAssertTrue(delegate.expansions.first?.0 === view)
        XCTAssertEqual(view.imageView.transform.a, -1, accuracy: 0.0001)
        XCTAssertEqual(view.imageView.transform.d, -1, accuracy: 0.0001)
        view.toggle()
        XCTAssertEqual(delegate.expansions.map(\.1), [true, false])
        XCTAssertEqual(view.imageView.transform, .identity)
        view.delegate = nil
        view.toggle()
        XCTAssertEqual(delegate.expansions.count, 2)
    }
}

private final class LegacyAlertControlDelegate: NSObject, RUAlertDetailsCellChildViewDelegate,
    RUAlertExpandButtonDelegate
{
    var descriptionTaps = [RUAlertDetailsCellChildView]()
    var expansions = [(RUAlertExpandButton, Bool)]()
    func didTapView(sender: RUAlertDetailsCellChildView) { descriptionTaps.append(sender) }
    func didTapButton(sender: RUAlertExpandButton, expanded: Bool) { expansions.append((sender, expanded)) }
}
