import UIKit
import XCTest
@testable import station

@MainActor final class MenuGestureContractTests: XCTestCase {
    func testOpeningWaitsForHorizontalMotionAndClampsProgressWithoutChangingTheViewTransform() throws {
        let root = GestureController()
        let host = try AppViewHost(root)
        defer { host.close() }
        let menu = GestureController()
        let manager = MenuTableTransitionManager(container: root, menu: menu)
        let transition = PresentGestureRecorder(manager: manager)
        let pan = MenuPan()
        root.view.addGestureRecognizer(pan)
        let transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        root.view.transform = transform
        pan.eventState = .began
        transition.handlePresentMenuPan(pan)
        XCTAssertFalse(manager.isInteractive)
        XCTAssertEqual(root.presentations, 0)
        pan.offset.x = MenuTableTransitionManager.appScreenRect.width * 0.25
        transition.handlePresentMenuPan(pan)
        XCTAssertTrue(manager.isInteractive)
        XCTAssertEqual(manager.presentDirection, .left)
        XCTAssertTrue(root.presented === menu)
        XCTAssertEqual(transition.progress.last ?? -1, 0.25, accuracy: 0.001)
        pan.eventState = .changed
        pan.offset.x *= 8
        transition.handlePresentMenuPan(pan)
        XCTAssertEqual(transition.progress.last, 1)
        XCTAssertEqual(root.presentations, 1)
        XCTAssertEqual(root.view.transform, transform)
    }

    func testOpeningFinishesForFastFlickOrHalfWidthAndCancelsShortOrReversedSwipes() throws {
        let root = GestureController()
        let host = try AppViewHost(root)
        defer { host.close() }
        for (fraction, velocity, finishes) in [
            (0.1, 100.0, true), (0.5, -50.0, true),
            (0.49, 0.0, false), (0.8, -51.0, false),
        ] {
            let manager = MenuTableTransitionManager(container: root, menu: GestureController())
            manager.isInteractive = true
            let transition = PresentGestureRecorder(manager: manager)
            let pan = MenuPan()
            root.view.addGestureRecognizer(pan)
            pan.eventState = .ended
            pan.offset.x = MenuTableTransitionManager.appScreenRect.width * fraction
            pan.speed.x = velocity
            transition.handlePresentMenuPan(pan)
            XCTAssertFalse(manager.isInteractive)
            XCTAssertEqual(transition.finishes, finishes ? 1 : 0)
            XCTAssertEqual(transition.cancels, finishes ? 0 : 1)
        }
    }

    func testClosingIgnoresTheWrongDirectionThenTracksAndCompletesAValidSwipe() throws {
        let root = GestureController()
        let host = try AppViewHost(root)
        defer { host.close() }
        let menu = GestureController()
        let manager = MenuTableTransitionManager(container: root, menu: menu)
        let transition = DismissGestureRecorder(manager: manager)
        let pan = MenuPan()
        menu.view.addGestureRecognizer(pan)
        pan.eventState = .began; pan.offset.x = 10
        transition.handleHideMenuPan(pan)
        XCTAssertFalse(manager.isInteractive)
        XCTAssertEqual(menu.dismissals, 0)
        pan.offset.x = -10
        transition.handleHideMenuPan(pan)
        XCTAssertTrue(manager.isInteractive)
        XCTAssertEqual(menu.dismissals, 1)
        for (fraction, expected) in [(-0.25, 0.0), (0.25, 0.25), (1.5, 1.0)] {
            pan.eventState = .changed
            pan.offset.x = -MenuTableTransitionManager.appScreenRect.width * fraction
            transition.handleHideMenuPan(pan)
            XCTAssertEqual(transition.progress.last ?? -1, expected, accuracy: 0.001)
        }
        pan.eventState = .ended; pan.speed.x = -100
        transition.handleHideMenuPan(pan)
        XCTAssertFalse(manager.isInteractive)
        XCTAssertEqual(transition.finishes, 1)
    }

    func testClosingCancelsShortSwipesAndFinishesHalfWidthSwipes() throws {
        let root = GestureController()
        let host = try AppViewHost(root)
        defer { host.close() }
        for (fraction, velocity, finishes) in [
            (0.1, -100.0, true), (0.5, 50.0, true),
            (0.49, 0.0, false), (0.8, 51.0, false),
        ] {
            let manager = MenuTableTransitionManager(container: root, menu: GestureController())
            manager.isInteractive = true
            let transition = DismissGestureRecorder(manager: manager)
            let pan = MenuPan()
            root.view.addGestureRecognizer(pan)
            pan.eventState = .ended
            pan.offset.x = -MenuTableTransitionManager.appScreenRect.width * fraction
            pan.speed.x = velocity
            transition.handleHideMenuPan(pan)
            XCTAssertFalse(manager.isInteractive)
            XCTAssertEqual(transition.finishes, finishes ? 1 : 0)
            XCTAssertEqual(transition.cancels, finishes ? 0 : 1)
        }
    }
}
private final class MenuPan: UIPanGestureRecognizer {
    var eventState: UIGestureRecognizer.State = .possible
    var offset = CGPoint.zero
    var speed = CGPoint.zero
    override var state: UIGestureRecognizer.State {
        get { eventState }
        set {}
    }
    override func translation(in view: UIView?) -> CGPoint { offset }
    override func velocity(in view: UIView?) -> CGPoint { speed }
}
private final class GestureController: UIViewController {
    var presentations = 0
    var dismissals = 0
    weak var presented: UIViewController?
    override func present(
        _ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil
    ) {
        presentations += 1; presented = viewControllerToPresent; completion?()
    }
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) { dismissals += 1; completion?() }
}
private final class PresentGestureRecorder: MenuTablePresentTransitionAnimation {
    var progress = [CGFloat]()
    var finishes = 0
    var cancels = 0
    override func update(_ percentComplete: CGFloat) { progress.append(percentComplete) }
    override func finish() { finishes += 1 }
    override func cancel() { cancels += 1 }
}
private final class DismissGestureRecorder: MenuTableDismissTransitionAnimation {
    var progress = [CGFloat]()
    var finishes = 0
    var cancels = 0
    override func update(_ percentComplete: CGFloat) { progress.append(percentComplete) }
    override func finish() { finishes += 1 }
    override func cancel() { cancels += 1 }
}
