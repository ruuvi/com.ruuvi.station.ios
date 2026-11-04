import UIKit
import XCTest
@testable import RuuviPresenters

@MainActor final class ActivityPresenterTests: XCTestCase {
    func testShowUpdatesExistingToastAndDismissesAtEveryPosition() async throws {
        let animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animations) }
        let host = UIViewController()
        host.loadViewIfNeeded()
        host.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        let presenter = ActivityPresenterRuuviLogo(topViewController: { host })
        for position: ActivityPresenterPosition in [.top, .bottom, .center] {
            presenter.show(with: .loading(message: "Loading"), atPosition: position)
            let toast = try XCTUnwrap(host.view.subviews.last)
            XCTAssertEqual(host.view.subviews.count, 1)
            XCTAssertTrue(toast.isUserInteractionEnabled)
            presenter.show(with: .success(message: "Saved"), atPosition: position)
            XCTAssertEqual(host.view.subviews.count, 1)
            XCTAssertTrue(host.view.subviews.last === toast)
            XCTAssertFalse(toast.isUserInteractionEnabled)
            XCTAssertEqual(host.view.gestureRecognizers?.count, 1)
            presenter.update(with: .failed(message: "Retry"))
            XCTAssertTrue(toast.isUserInteractionEnabled)
            XCTAssertTrue(host.view.gestureRecognizers?.isEmpty ?? true)
            presenter.dismiss(immediately: true)
            await nextMainQueueTurn()
            XCTAssertNil(toast.superview)
        }
    }

    func testPendingDismissalCannotRemoveNewerStatusAndSuccessTapPassesThrough() async throws {
        let animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animations) }
        let host = UIViewController()
        host.loadViewIfNeeded()
        let presenter = ActivityPresenterRuuviLogo(topViewController: { host })
        presenter.show(with: .success(message: "Saved"), atPosition: .bottom)
        presenter.dismiss(immediately: false)
        presenter.update(with: .loading(message: "Next task"))
        let elapsed = expectation(description: "Original dismissal deadline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { elapsed.fulfill() }
        await fulfillment(of: [elapsed], timeout: 3)
        XCTAssertEqual(host.view.subviews.count, 1)
        XCTAssertFalse(presenter.gestureRecognizer(UITapGestureRecognizer(), shouldReceive: UITouch()))
        await nextMainQueueTurn()
        XCTAssertEqual(host.view.subviews.count, 1, "Loading should survive unrelated touches")
        presenter.update(with: .success(message: nil))
        XCTAssertFalse(presenter.gestureRecognizer(UITapGestureRecognizer(), shouldReceive: UITouch()))
        await nextMainQueueTurn()
        XCTAssertTrue(host.view.subviews.isEmpty)
        XCTAssertTrue(host.view.gestureRecognizers?.isEmpty ?? true)
    }

    func testToastMovesToCurrentHostAndMissingHostIsHarmless() async {
        let animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animations) }
        let first = UIViewController()
        let second = UIViewController()
        var host: UIViewController? = first
        let presenter = ActivityPresenterRuuviLogo(topViewController: { host })
        presenter.show(with: .loading(message: nil), atPosition: .top)
        XCTAssertEqual(first.view.subviews.count, 1)
        host = second
        presenter.show(with: .success(message: nil), atPosition: .center)
        XCTAssertTrue(first.view.subviews.isEmpty)
        XCTAssertEqual(second.view.subviews.count, 1)
        host = nil
        presenter.show(with: .failed(message: nil), atPosition: .bottom)
        presenter.dismiss(immediately: true)
        await nextMainQueueTurn()
        XCTAssertTrue(second.view.subviews.isEmpty)
    }

    private func nextMainQueueTurn() async {
        let completion = expectation(description: "Main queue settled")
        DispatchQueue.main.async { completion.fulfill() }
        await fulfillment(of: [completion], timeout: 2)
    }
}
