@testable import station
import XCTest

@MainActor
final class SnackbarDragTests: XCTestCase {
    private var window: UIWindow!
    private var animationsWereEnabled = true

    override func setUpWithError() throws {
        try super.setUpWithError()
        animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.windowLevel = .alert + 1
        window.rootViewController = UIViewController()
        window.rootViewController?.view.backgroundColor = .systemBackground
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        UIView.setAnimationsEnabled(animationsWereEnabled)
        super.tearDown()
    }

    func testDownwardDragTracksFingerAndFinishesBelowScreen() throws {
        UIView.setAnimationsEnabled(true)
        let animator = SnackbarTestAnimator()
        let presenter = SnackbarPresenter(duration: 5, reduceMotion: { false }, animate: animator.animate)
        let (message, pan) = try show(presenter)
        send(.began, pan: pan, to: presenter)
        send(.changed, y: message.bounds.height, pan: pan, to: presenter)
        XCTAssertEqual(message.transform.ty, message.bounds.height, accuracy: 0.1)
        XCTAssertEqual(message.transform.tx, 0)
        XCTAssertEqual(message.alpha, 1)
        attachDragPreview()
        send(.ended, pan: pan, to: presenter)
        XCTAssertTrue(presenter.isPresented)
        XCTAssertGreaterThanOrEqual(message.frame.minY, host.bounds.maxY)
        XCTAssertNil(message.layer.animation(forKey: "opacity"))
        animator.finishAll()
        XCTAssertFalse(presenter.isPresented)
        XCTAssertNil(message.superview)
    }

    func testShortDragPausesTimerThenSnapsBackAndRestartsIt() throws {
        let clock = SnackbarTestClock()
        let presenter = SnackbarPresenter(
            animationDuration: 0, schedule: clock.schedule, animate: SnackbarTestAnimator.immediately
        )
        let (message, pan) = try show(presenter)
        send(.began, pan: pan, to: presenter)
        send(.changed, y: 12, pan: pan, to: presenter)
        clock.advance(by: 3)
        XCTAssertTrue(presenter.isPresented)
        XCTAssertEqual(message.transform.ty, 12)
        send(.changed, y: -20, pan: pan, to: presenter)
        XCTAssertEqual(message.transform, .identity)
        send(.changed, y: 12, pan: pan, to: presenter)
        send(.ended, pan: pan, to: presenter)
        XCTAssertTrue(presenter.isPresented)
        XCTAssertEqual(message.transform, .identity)
        clock.advance(by: 3)
        XCTAssertFalse(presenter.isPresented)
    }

    func testQuickDownwardSwipeDismissesEvenWithLittleTravel() throws {
        let presenter = SnackbarPresenter(animationDuration: 0)
        let (message, pan) = try show(presenter)
        send(.began, pan: pan, to: presenter)
        // A quick flick can end before UIKit delivers an intermediate changed event.
        send(.ended, y: 5, velocity: 800, pan: pan, to: presenter)
        XCTAssertFalse(presenter.isPresented)
        XCTAssertNil(message.superview)
    }

    func testCancelledOrFailedDragReturnsToRestEvenAfterPassingDismissalDistance() throws {
        let presenter = SnackbarPresenter(animationDuration: 0)
        for state in [UIGestureRecognizer.State.cancelled, .failed] {
            let (message, pan) = try show(presenter)
            send(.began, pan: pan, to: presenter)
            send(.changed, y: message.bounds.height, pan: pan, to: presenter)
            send(state, pan: pan, to: presenter)
            XCTAssertTrue(presenter.isPresented)
            XCTAssertEqual(message.transform, .identity)
            presenter.dismiss(animated: false)
        }
    }

    func testOnlyPredominantlyDownwardPansBegin() throws {
        let presenter = SnackbarPresenter(animationDuration: 0)
        let (message, pan) = try show(presenter)
        let installed = try XCTUnwrap(message.gestureRecognizers?.first as? UIPanGestureRecognizer)
        XCTAssertEqual(installed.maximumNumberOfTouches, 1)
        XCTAssertTrue(installed.delegate === presenter)
        for velocity in [CGPoint(x: 800, y: 0), CGPoint(x: 0, y: -800), CGPoint(x: 200, y: 100)] {
            pan.testVelocity = velocity
            XCTAssertFalse(presenter.gestureRecognizerShouldBegin(pan))
        }
        pan.testVelocity = CGPoint(x: 10, y: 100)
        XCTAssertTrue(presenter.gestureRecognizerShouldBegin(pan))
        presenter.dismiss(animated: false)
    }

    func testBackgroundDuringDragClearsItAndOldGestureCannotAffectNextMessage() throws {
        let center = NotificationCenter()
        let clock = SnackbarTestClock()
        let presenter = SnackbarPresenter(animationDuration: 0, notificationCenter: center, schedule: clock.schedule)
        let (_, pan) = try show(presenter)
        send(.began, pan: pan, to: presenter)
        send(.changed, y: 30, pan: pan, to: presenter)
        center.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertFalse(presenter.isPresented)
        _ = try show(presenter)
        send(.cancelled, pan: pan, to: presenter)
        XCTAssertTrue(presenter.isPresented)
        clock.advance(by: 3)
        XCTAssertFalse(presenter.isPresented)
        XCTAssertTrue(host.subviews.isEmpty)
    }

    func testAccessibilityEscapeDismissesTheSnackbar() throws {
        let presenter = SnackbarPresenter(animationDuration: 0)
        let (message, _) = try show(presenter)
        XCTAssertTrue(message.accessibilityPerformEscape())
        XCTAssertFalse(presenter.isPresented)
    }
}

private extension SnackbarDragTests {
    var host: UIView { window.rootViewController!.view! }

    func show(_ presenter: SnackbarPresenter) throws -> (SnackbarView, TestSnackbarPan) {
        XCTAssertTrue(presenter.show(message: "Measurements may be outdated.", in: host))
        let message = try XCTUnwrap(host.subviews.first { $0 is SnackbarView } as? SnackbarView)
        let pan = TestSnackbarPan()
        message.addGestureRecognizer(pan)
        return (message, pan)
    }

    func send(
        _ state: UIGestureRecognizer.State, y: CGFloat? = nil, velocity: CGFloat = 0,
        pan: TestSnackbarPan, to presenter: SnackbarPresenter
    ) {
        pan.testState = state
        if let y { pan.testTranslation = CGPoint(x: 0, y: y) }
        pan.testVelocity = CGPoint(x: 0, y: velocity)
        presenter.handlePan(pan)
    }

    func attachDragPreview() {
        let image = UIGraphicsImageRenderer(bounds: host.bounds).image { _ in
            XCTAssertTrue(host.drawHierarchy(in: host.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "snackbar-following-downward-drag"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private final class TestSnackbarPan: UIPanGestureRecognizer {
    var testState: UIGestureRecognizer.State = .possible
    var testTranslation = CGPoint.zero
    var testVelocity = CGPoint.zero

    override var state: UIGestureRecognizer.State {
        get { testState }
        set { testState = newValue }
    }

    override func translation(in view: UIView?) -> CGPoint { testTranslation }
    override func setTranslation(_ translation: CGPoint, in view: UIView?) { testTranslation = translation }
    override func velocity(in view: UIView?) -> CGPoint { testVelocity }
}
