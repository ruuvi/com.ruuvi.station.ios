import UIKit
import XCTest
@testable import station

@MainActor final class SensorNameSwipeTests: XCTestCase {
    func testHorizontalGestureRequiresAnAvailableNeighbourAndRejectsVerticalMotion() {
        let view = makeView()
        let gesture = SensorNamePan()
        for (velocity, allowed): (CGPoint, Bool) in [
            (CGPoint(x: -100, y: 0), true), (CGPoint(x: 100, y: 0), true),
            (CGPoint(x: 10, y: 100), false), (.zero, false),
        ] {
            gesture.motion = velocity
            XCTAssertEqual(view.gestureRecognizerShouldBegin(gesture), allowed)
        }
        view.configure(current: "Only", previous: nil, next: nil)
        gesture.motion = CGPoint(x: -100, y: 0)
        XCTAssertFalse(view.gestureRecognizerShouldBegin(gesture))
        XCTAssertFalse(view.gestureRecognizerShouldBegin(UITapGestureRecognizer()))
        XCTAssertEqual(view.accessibilityLabel, "Only")
        XCTAssertGreaterThan(view.intrinsicContentSize.height, 0)
    }

    func testCompletedSwipeShowsPendingNameAndKeepsTheHeaderAccessible() async {
        let animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animations) }
        let view = makeView()
        var requests = [CardsSensorNameSwipeView.NavigationDirection]()
        view.onNavigate = { direction in
            requests.append(direction)
            view.configure(current: "Next sensor", previous: "Current", next: nil)
            return true
        }
        send(view, state: .began)
        send(view, state: .changed, translation: -220)
        XCTAssertEqual(view.text, "Current")
        XCTAssertEqual(view.allDescendants.compactMap { ($0 as? UILabel)?.text }, ["Current", "Next"])
        send(view, state: .ended, velocity: -800)
        await waitForAppState("swipe commits") { view.text == "Next sensor" }
        XCTAssertEqual(requests, [.next])
        XCTAssertEqual(view.accessibilityLabel, "Next sensor")
        XCTAssertEqual(view.allDescendants.compactMap { $0 as? UILabel }.first?.frame.origin.x, 0)
    }

    func testShortCancelledAndRejectedSwipesRestoreTheOriginalPosition() async {
        let animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animations) }
        let view = makeView()
        var requests = 0
        view.onNavigate = { _ in
            requests += 1; return false
        }
        for (translation, state): (CGFloat, UIGestureRecognizer.State) in [
            (-20, .ended), (220, .cancelled), (220, .failed), (220, .ended),
        ] {
            send(view, state: .began)
            send(view, state: .changed, translation: translation)
            send(view, state: state, velocity: 0)
            await waitForAppState("swipe rolls back") {
                view.allDescendants.compactMap { $0 as? UILabel }.first?.frame.origin.x == 0
            }
            XCTAssertEqual(view.text, "Current")
            XCTAssertEqual(view.accessibilityLabel, "Current")
        }
        XCTAssertEqual(requests, 1)
    }

    func testFastSwipeCompletesBeforeHalfwayButOppositeVelocityDoesNot() async {
        let animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animations) }
        let view = makeView()
        var requests = [CardsSensorNameSwipeView.NavigationDirection]()
        view.onNavigate = {
            requests.append($0); return true
        }
        send(view, state: .began)
        send(view, state: .changed, translation: 20)
        send(view, state: .ended, velocity: -800)
        await flushAppBindings()
        XCTAssertTrue(requests.isEmpty)
        send(view, state: .began)
        send(view, state: .changed, translation: 20)
        send(view, state: .ended, velocity: 800)
        await waitForAppState("fast previous swipe") { requests.count == 1 }
        XCTAssertEqual(requests, [.previous])
    }

    private func makeView() -> CardsSensorNameSwipeView {
        let view = CardsSensorNameSwipeView(font: .systemFont(ofSize: 20), numberOfLines: 2)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 64)
        view.configure(current: "Current", previous: "Previous", next: "Next")
        view.layoutIfNeeded()
        return view
    }
    private func send(
        _ view: CardsSensorNameSwipeView, state: UIGestureRecognizer.State,
        translation: CGFloat = 0, velocity: CGFloat = 0
    ) {
        let gesture = SensorNamePan()
        gesture.eventState = state
        gesture.offset = CGPoint(x: translation, y: 0)
        gesture.motion = CGPoint(x: velocity, y: 0)
        view.perform(NSSelectorFromString("handlePanGesture:"), with: gesture)
        view.layoutIfNeeded()
    }
}

private final class SensorNamePan: UIPanGestureRecognizer {
    var eventState: UIGestureRecognizer.State = .possible
    var offset = CGPoint.zero
    var motion = CGPoint.zero
    override var state: UIGestureRecognizer.State {
        get { eventState }
        set { eventState = newValue }
    }
    override func translation(in view: UIView?) -> CGPoint { offset }
    override func velocity(in view: UIView?) -> CGPoint { motion }
}
