import UIKit
import XCTest
@testable import RuuviOnboard

@MainActor final class OnboardLayoutTests: XCTestCase {
    func testAnchorsRespectInsetsAndTheirReturnedConstraintsRemainEditable() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 700))
        let child = UIView()
        parent.addSubview(child)
        let constraints = child.anchor(
            top: parent.topAnchor, leading: parent.leadingAnchor,
            bottom: parent.bottomAnchor, trailing: parent.trailingAnchor,
            padding: UIEdgeInsets(top: 10, left: 20, bottom: 30, right: 40))
        parent.layoutIfNeeded()
        XCTAssertEqual(child.frame, CGRect(x: 20, y: 10, width: 340, height: 660))
        XCTAssertFalse(child.translatesAutoresizingMaskIntoConstraints)
        constraints.top?.constant = 50
        parent.setNeedsLayout(); parent.layoutIfNeeded()
        XCTAssertEqual(child.frame, CGRect(x: 20, y: 50, width: 340, height: 620))
    }

    func testLeadingBoundsKeepSizedContentCenteredInsideItsAvailableWidth() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 700))
        let child = UIView()
        parent.addSubview(child)
        child.anchorLeading(
            top: parent.topAnchor, leading: parent.leadingAnchor,
            bottom: nil, trailing: parent.trailingAnchor,
            padding: UIEdgeInsets(top: 15, left: 20, bottom: 0, right: 20), size: CGSize(width: 180, height: 60))
        child.centerXInSuperview()
        parent.layoutIfNeeded()
        XCTAssertEqual(child.frame, CGRect(x: 110, y: 15, width: 180, height: 60))
        XCTAssertFalse(child.hasAmbiguousLayout)
    }

    func testFillSafeAreaCenterAndMatchProduceTheExpectedFrames() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 700))
        let filled = UIView()
        parent.addSubview(filled)
        filled.fillSuperview(padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        let safe = UIView()
        parent.addSubview(safe)
        safe.fillSuperviewToSafeArea(padding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
        let centered = UIView()
        parent.addSubview(centered)
        centered.centerInSuperview(size: CGSize(width: 100, height: 80))
        let matched = UIView()
        parent.addSubview(matched)
        matched.match(view: centered)
        parent.layoutIfNeeded()
        XCTAssertEqual(filled.frame, parent.bounds.insetBy(dx: 10, dy: 10))
        XCTAssertEqual(safe.frame, parent.safeAreaLayoutGuide.layoutFrame.insetBy(dx: 20, dy: 20))
        XCTAssertEqual(centered.frame, CGRect(x: 150, y: 310, width: 100, height: 80))
        XCTAssertEqual(matched.frame, centered.frame)
    }

    func testSizeAndMinimumConstraintsCanBeCombinedWithoutAmbiguousLayout() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 700))
        let child = UIView()
        parent.addSubview(child)
        child.constrainWidth(constant: 160)
        child.constrainHeight(constant: 70)
        child.widthGreaterThanOrEqualTo(constant: 100)
        child.widthLessThanOrEqualTo(constant: 200)
        child.heightGreaterThanOrEqualTo(constant: 50)
        child.centerXInSuperview(); child.centerYInSuperview()
        let other = UIView()
        parent.addSubview(other)
        other.size(width: 80, height: 40)
        other.centerInSuperview()
        parent.layoutIfNeeded()
        XCTAssertEqual(child.frame, CGRect(x: 120, y: 315, width: 160, height: 70))
        XCTAssertEqual(other.frame, CGRect(x: 160, y: 330, width: 80, height: 40))
        XCTAssertFalse(child.hasAmbiguousLayout)
        XCTAssertFalse(other.hasAmbiguousLayout)
        XCTAssertGreaterThanOrEqual(parent.bottomSafeAreaHeight, 0)
    }
}
