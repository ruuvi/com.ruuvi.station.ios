import UIKit
import XCTest
@testable import station

@MainActor final class SwipeDismissContractTests: XCTestCase {
    func testDismissalStartsOnlyWhenTheTopTableHasReachedItsTopEdge() {
        let table = UITableViewController()
        let navigation = SwipeNavigationSpy(rootViewController: table)
        let transition = SwipeDownToDismissTransitioningDelegate()
        navigation.transitioningDelegate = transition
        navigation.loadViewIfNeeded()
        XCTAssertTrue(navigation.view.gestureRecognizers?.contains(navigation.panGR) == true)
        XCTAssertTrue(
            navigation.gestureRecognizer(
                navigation.panGR, shouldRecognizeSimultaneouslyWith: table.tableView.panGestureRecognizer))
        let gesture = MasonryPan()
        gesture.state = .began
        table.tableView.contentOffset.y = 30
        navigation.handlePanGesture(gesture)
        XCTAssertEqual(navigation.dismissals, 0)
        XCTAssertFalse(transition.interactionControllerForDismissal.hasStarted)
        table.tableView.contentOffset.y = 0
        navigation.handlePanGesture(gesture)
        XCTAssertEqual(navigation.dismissals, 1)
        XCTAssertTrue(transition.interactionControllerForDismissal.hasStarted)
        gesture.state = .cancelled
        navigation.handlePanGesture(gesture)
        XCTAssertFalse(transition.interactionControllerForDismissal.hasStarted)
        navigation.setViewControllers([UIViewController()], animated: false)
        gesture.state = .began
        navigation.handlePanGesture(gesture)
        XCTAssertEqual(navigation.dismissals, 1)
    }

    func testDownwardGestureRequiresTheExistingFinishThreshold() {
        let navigation = SwipeNavigationSpy(rootViewController: UITableViewController())
        let transition = SwipeDownToDismissTransitioningDelegate()
        navigation.transitioningDelegate = transition
        navigation.loadViewIfNeeded()
        navigation.view.frame = CGRect(x: 0, y: 0, width: 320, height: 500)
        let interactor = transition.interactionControllerForDismissal
        let gesture = MasonryPan()
        gesture.state = .changed
        for (distance, shouldFinish): (CGFloat, Bool) in [
            (-100, false), (0, false), (100, false), (200, true), (1000, true),
        ] {
            gesture.offset.y = distance
            navigation.handlePanGesture(gesture)
            XCTAssertEqual(interactor.shouldFinish, shouldFinish)
        }
        interactor.hasStarted = true
        gesture.state = .ended
        navigation.handlePanGesture(gesture)
        XCTAssertFalse(interactor.hasStarted)
        interactor.shouldFinish = false
        interactor.hasStarted = true
        navigation.handlePanGesture(gesture)
        XCTAssertFalse(interactor.hasStarted)
        gesture.state = .possible
        navigation.handlePanGesture(gesture)
        XCTAssertEqual(navigation.dismissals, 0)
    }
}
private final class SwipeNavigationSpy: SwipeDownToDismissNavigationController {
    var dismissals = 0
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) { dismissals += 1; completion?() }
}
