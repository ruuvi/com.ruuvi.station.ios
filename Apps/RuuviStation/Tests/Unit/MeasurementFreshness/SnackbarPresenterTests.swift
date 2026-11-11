@testable import station
import XCTest

@MainActor
final class SnackbarPresenterTests: XCTestCase {
    private var window: UIWindow!
    private var animationsWereEnabled = true
    private var host: UIView { window.rootViewController!.view! }

    override func setUpWithError() throws {
        try super.setUpWithError()
        animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(true)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.windowLevel = .alert + 1
        window.rootViewController = UIViewController()
        host.backgroundColor = .systemBackground
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        UIView.setAnimationsEnabled(animationsWereEnabled)
        super.tearDown()
    }

    func testShowAndHideSlideWithoutQueuing() throws {
        let animator = SnackbarTestAnimator()
        var startingTop: CGFloat = 0
        animator.beforeAnimation = { startingTop = self.host.subviews.last?.frame.minY ?? 0 }
        let presenter = SnackbarPresenter(duration: 5, reduceMotion: { false }, animate: animator.animate)
        XCTAssertTrue(presenter.show(message: "Measurements may be outdated.", in: host))
        let message = try XCTUnwrap(host.subviews.first { $0 is SnackbarView })
        XCTAssertGreaterThanOrEqual(startingTop, host.bounds.maxY)
        XCTAssertEqual(message.alpha, 1)
        XCTAssertEqual(message.transform, .identity)
        presenter.dismiss()
        XCTAssertTrue(presenter.isPresented)
        XCTAssertGreaterThanOrEqual(message.frame.minY, host.bounds.maxY)
        XCTAssertEqual(message.alpha, 1)
        XCTAssertFalse(presenter.show(message: "Do not queue this", in: host))
        animator.finishAll()
        XCTAssertFalse(presenter.isPresented)
        XCTAssertNil(message.superview)
    }

    func testReduceMotionFadesAndOldExitCannotRemoveReplacement() throws {
        let animator = SnackbarTestAnimator()
        let center = NotificationCenter()
        var startingAlpha: CGFloat = 1
        animator.beforeAnimation = { startingAlpha = self.host.subviews.last?.alpha ?? 1 }
        let presenter = SnackbarPresenter(notificationCenter: center, reduceMotion: { true }, animate: animator.animate)
        XCTAssertTrue(presenter.show(message: "First", in: host))
        let first = try XCTUnwrap(host.subviews.first { $0 is SnackbarView })
        XCTAssertEqual(startingAlpha, 0)
        XCTAssertEqual(first.transform, .identity)
        presenter.dismiss()
        XCTAssertEqual(first.alpha, 0)
        XCTAssertEqual(first.transform, .identity)
        center.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertFalse(presenter.isPresented)
        XCTAssertTrue(presenter.show(message: "Second", in: host))
        animator.finishAll()
        XCTAssertTrue(presenter.isPresented)
        XCTAssertEqual(host.subviews.count, 1)
        presenter.dismiss(animated: false)
    }

    func testDefaultThreeSecondDeadlineDoesNotReplayIgnoredRequests() {
        let clock = SnackbarTestClock()
        let presenter = SnackbarPresenter(schedule: clock.schedule, animate: SnackbarTestAnimator.immediately)
        XCTAssertTrue(presenter.show(message: "First", in: host))
        XCTAssertFalse(presenter.show(message: "Ignored", in: host))
        clock.advance(by: 2.999)
        XCTAssertTrue(presenter.isPresented)
        clock.advance(by: 0.001)
        XCTAssertFalse(presenter.isPresented)
        clock.advance(by: 100)
        XCTAssertTrue(host.subviews.isEmpty)
    }

    func testSecondSensorRetargetsAndRestartsDeadlineWithoutQueueing() {
        let clock = SnackbarTestClock()
        let snackbar = SnackbarPresenter(schedule: clock.schedule, animate: SnackbarTestAnimator.immediately)
        let presenter = MeasurementWarningPresenter(snackbar: snackbar)
        XCTAssertTrue(presenter.show(for: "A", in: host))
        clock.advance(by: 2)
        XCTAssertTrue(presenter.show(for: "B", in: host))
        XCTAssertEqual(presenter.sensorID, "B")
        XCTAssertEqual(host.subviews.count, 1)
        presenter.dismiss(for: "A")
        clock.advance(by: 2)
        XCTAssertEqual(presenter.sensorID, "B")
        XCTAssertFalse(presenter.show(for: "B", in: host))
        clock.advance(by: 1)
        XCTAssertNil(presenter.sensorID)
        XCTAssertTrue(host.subviews.isEmpty)
    }

    func testSecondSensorDuringExitReplacesMessageAndOldCompletionIsHarmless() {
        let animator = SnackbarTestAnimator()
        let presenter = MeasurementWarningPresenter(snackbar: SnackbarPresenter(animate: animator.animate))
        XCTAssertTrue(presenter.show(for: "A", in: host))
        presenter.dismiss(for: "A")
        XCTAssertTrue(presenter.show(for: "B", in: host))
        animator.finishAll()
        XCTAssertEqual(presenter.sensorID, "B")
        XCTAssertEqual(host.subviews.count, 1)
        presenter.dismiss(animated: false)
    }

    func testPresenterIsReusableWithAnyMessageAndRequiresAVisibleHost() throws {
        let presenter = SnackbarPresenter(animationDuration: 0)
        XCTAssertFalse(presenter.show(message: "Hidden", in: UIView()))
        for text in ["Saved", "Updated"] {
            XCTAssertTrue(presenter.show(message: text, in: host))
            let message = try XCTUnwrap(host.subviews.first { $0 is SnackbarView })
            XCTAssertEqual(message.subviews.compactMap { $0 as? UILabel }.first?.text, text)
            presenter.dismiss()
            XCTAssertTrue(host.subviews.isEmpty)
        }
    }

    func testUIKitSlideCompletesAndRendersInVisibleWindow() async throws {
        let entered = expectation(description: "Entry animation completed")
        let exited = expectation(description: "Exit animation completed")
        var entering = true
        let animation: SnackbarPresenter.Animate = { duration, options, changes, done in
            let completion = entering ? entered : exited
            entering = false
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: changes) { finished in
                XCTAssertTrue(finished)
                done?(finished)
                completion.fulfill()
            }
        }
        let presenter = SnackbarPresenter(duration: 30, reduceMotion: { false }, animate: animation)
        XCTAssertTrue(presenter.show(message: "Measurements may be outdated.", in: host))
        await fulfillment(of: [entered], timeout: 5)
        let message = try XCTUnwrap(host.subviews.first { $0 is SnackbarView })
        XCTAssertEqual(message.alpha, 1)
        XCTAssertEqual(message.transform, .identity)
        let image = UIGraphicsImageRenderer(bounds: host.bounds).image { _ in
            XCTAssertTrue(host.drawHierarchy(in: host.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "snackbar-visible-after-real-slide"
        attachment.lifetime = .keepAlways
        add(attachment)
        presenter.dismiss()
        await fulfillment(of: [exited], timeout: 5)
        XCTAssertFalse(presenter.isPresented)
    }
}
