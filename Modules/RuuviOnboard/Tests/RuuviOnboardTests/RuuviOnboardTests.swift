import UIKit
import XCTest
import RuuviUser
@testable import RuuviOnboard

final class RuuviOnboardTests: XCTestCase {
    @MainActor func testEveryOnboardingPageLoadsAndCanBeReached() throws {
        let pages = RuuviOnboardPages(ruuviUser: OnboardUser(), tosAccepted: false, analyticsConsentGiven: false)
        let controller = try XCTUnwrap(pages.viewController as? RuuviOnboardViewController)
        XCTAssertTrue(pages.viewController === controller)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        controller.view.layoutIfNeeded()
        let collection = try XCTUnwrap(descendants(of: controller.view, as: UICollectionView.self).first)
        XCTAssertEqual(collection.numberOfItems(inSection: 0), 9)
        for index in 0..<9 {
            collection.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: false)
            collection.layoutIfNeeded()
            XCTAssertNotNil(collection.cellForItem(at: IndexPath(item: index, section: 0)), "Page \(index)")
        }
        XCTAssertTrue(collection.visibleCells.contains { $0 is RuuviOnboardSignInCell })
    }

    @MainActor func testContinueRoutesSignedOutUsersToSignInAndSignedInUsersToDiscovery() throws {
        for authorized in [false, true] {
            let user = OnboardUser()
            user.isAuthorized = authorized
            let pages = RuuviOnboardPages(ruuviUser: user, tosAccepted: true, analyticsConsentGiven: true)
            let output = OnboardOutputSpy()
            pages.output = output
            let controller = try XCTUnwrap(pages.viewController as? RuuviOnboardViewController)
            controller.loadViewIfNeeded()
            controller.didTapContinueButton(sender: RuuviOnboardSignInCell(frame: .zero))
            XCTAssertEqual(output.signIns, authorized ? 0 : 1)
            XCTAssertEqual(output.finishes, authorized ? 1 : 0)
        }
    }

    @MainActor func testAnalyticsConsentChangesReachTheApplication() throws {
        let pages = RuuviOnboardPages(ruuviUser: OnboardUser(), tosAccepted: true, analyticsConsentGiven: false)
        let output = OnboardOutputSpy()
        pages.output = output
        let controller = try XCTUnwrap(pages.viewController as? RuuviOnboardViewController)
        let cell = RuuviOnboardSignInCell(frame: .zero)
        controller.didProvideAnalyticsConsent(isConsentGiven: true, sender: cell)
        controller.didProvideAnalyticsConsent(isConsentGiven: false, sender: cell)
        XCTAssertEqual(output.consents, [true, false])
    }

    @MainActor func testSkipGoesToFinalPageAndPagingBackRestoresTheSkipButton() throws {
        let pages = RuuviOnboardPages(ruuviUser: OnboardUser(), tosAccepted: false, analyticsConsentGiven: false)
        let controller = try XCTUnwrap(pages.viewController as? RuuviOnboardViewController)
        let navigation = UINavigationController(rootViewController: controller)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = navigation
        defer { window.rootViewController = nil }
        controller.loadViewIfNeeded()
        controller.view.frame = window.bounds
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        controller.view.layoutIfNeeded()
        XCTAssertTrue(navigation.isNavigationBarHidden)
        let collection = try XCTUnwrap(descendants(of: controller.view, as: UICollectionView.self).first)
        let control = try XCTUnwrap(descendants(of: controller.view, as: UIPageControl.self).first)
        let skip = try XCTUnwrap(
            descendants(of: controller.view, as: UIButton.self).first {
                $0.actions(forTarget: controller, forControlEvent: .touchUpInside)?.contains("handleSkipButtonTap")
                    == true
            })
        XCTAssertFalse(skip.isHidden)
        // Exercise the registered target/action directly in the framework test host.
        let action = try XCTUnwrap(skip.actions(forTarget: controller, forControlEvent: .touchUpInside)?.first)
        controller.perform(NSSelectorFromString(action))
        collection.layoutIfNeeded()
        XCTAssertEqual(control.currentPage, collection.numberOfItems(inSection: 0) - 1)
        XCTAssertTrue(skip.isHidden)
        collection.scrollToItem(at: IndexPath(item: 2, section: 0), at: .centeredHorizontally, animated: false)
        collection.layoutIfNeeded()
        controller.scrollViewDidEndDecelerating(collection)
        XCTAssertEqual(control.currentPage, 2)
        XCTAssertFalse(skip.isHidden)
    }

    @MainActor func testAcceptedTermsWithMissingAnalyticsConsentStartsAtConsentPage() throws {
        let pages = RuuviOnboardPages(ruuviUser: OnboardUser(), tosAccepted: true, analyticsConsentGiven: false)
        let controller = try XCTUnwrap(pages.viewController as? RuuviOnboardViewController)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        controller.view.layoutIfNeeded()
        let control = try XCTUnwrap(descendants(of: controller.view, as: UIPageControl.self).first)
        XCTAssertEqual(control.currentPage, control.numberOfPages - 1)
    }

    @MainActor private func descendants<View: UIView>(of view: UIView, as type: View.Type) -> [View] {
        view.subviews.flatMap { child in
            (child as? View).map { [$0] } ?? descendants(of: child, as: type)
        }
    }
}

private final class OnboardUser: RuuviUser {
    var apiKey: String? = nil
    var email: String? = nil
    var isAuthorized = false
    func login(apiKey: String) { self.apiKey = apiKey; isAuthorized = true }
    func logout() { apiKey = nil; isAuthorized = false }
}

private final class OnboardOutputSpy: RuuviOnboardOutput {
    var signIns = 0
    var finishes = 0
    var consents = [Bool]()
    func ruuviOnboardDidFinish(_ ruuviOnboard: RuuviOnboard) { finishes += 1 }
    func ruuviOnboardDidShowSignIn(_ ruuviOnboard: RuuviOnboard) { signIns += 1 }
    func ruuviOnboardDidProvideAnalyticsConsent(_ ruuviOnboard: RuuviOnboard, consentGiven: Bool) {
        consents.append(consentGiven)
    }
}
