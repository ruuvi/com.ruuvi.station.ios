import RuuviLocalization
import XCTest
@testable import station

@MainActor final class MenuPresenterTests: XCTestCase {
    func testEveryMenuDestinationAndAccountStateAreForwardedToTheParent() {
        let presenter = MenuPresenter()
        let output = MenuOutputSpy()
        let router = MenuRouterSpy()
        let user = DefaultsUserSpy()
        presenter.router = router
        presenter.ruuviUser = user
        presenter.configure(output: output)
        presenter.viewWillAppear()
        presenter.viewDidSelectAddRuuviTag()
        presenter.viewDidSelectSettings()
        presenter.viewDidSelectAbout()
        presenter.viewDidSelectWhatToMeasure()
        presenter.viewDidSelectGetMoreSensors()
        presenter.viewDidSelectFeedback()
        presenter.viewDidSelectAccountCell()
        presenter.viewDidSelectNewsletter()
        XCTAssertEqual(
            output.destinations, ["add", "settings", "about", "measure", "shop", "feedback", "signIn", "newsletter"])
        XCTAssertEqual(output.newsletter?.absoluteString, RuuviLocalization.newsletterUrl)
        XCTAssertFalse(presenter.userIsAuthorized)
        XCTAssertNil(presenter.userEmail)
        user.isAuthorized = true
        user.email = "OWNER@Example.com"
        XCTAssertTrue(presenter.userIsAuthorized)
        XCTAssertEqual(presenter.userEmail, "owner@example.com")
        presenter.viewDidSelectAccountCell()
        presenter.viewDidSelectNewsletter()
        XCTAssertEqual(Array(output.destinations.suffix(2)), ["account", "account"])
        presenter.viewDidTapOnDimmingView()
        presenter.dismiss()
        XCTAssertEqual(router.dismissals, 2)
    }

    func testNewsletterVisibilityHonorsFeatureFlagAuthorizationAndExistingConsent() {
        let presenter = MenuPresenter()
        let flags = AppTestFlags()
        let user = DefaultsUserSpy()
        let settings = AppTestSettings()
        presenter.flags = flags
        presenter.ruuviUser = user
        presenter.settings = settings
        for enabled in [false, true] {
            for authorized in [false, true] {
                for consent in [false, true] {
                    flags.showMarketingPreference = enabled
                    user.isAuthorized = authorized
                    settings.marketingPreference = consent
                    XCTAssertEqual(presenter.shouldShowNewsletter, enabled && (!authorized || !consent))
                }
            }
        }
    }

    func testMenuDoesNotKeepDismissedParentAlive() {
        let presenter = MenuPresenter()
        var output: MenuOutputSpy? = MenuOutputSpy()
        weak var weakOutput = output
        presenter.configure(output: output!)
        output = nil
        XCTAssertNil(weakOutput)
        presenter.viewDidSelectAddRuuviTag()
    }
}

private final class MenuRouterSpy: MenuRouterInput {
    var dismissals = 0
    func dismiss() { dismissals += 1 }
}

private final class MenuOutputSpy: MenuModuleOutput {
    var destinations = [String]()
    var newsletter: URL?
    func menu(module: MenuModuleInput, didSelectAddRuuviTag sender: Any?) { destinations.append("add") }
    func menu(module: MenuModuleInput, didSelectSettings sender: Any?) { destinations.append("settings") }
    func menu(module: MenuModuleInput, didSelectAbout sender: Any?) { destinations.append("about") }
    func menu(module: MenuModuleInput, didSelectWhatToMeasure sender: Any?) { destinations.append("measure") }
    func menu(module: MenuModuleInput, didSelectGetMoreSensors sender: Any?) { destinations.append("shop") }
    func menu(module: MenuModuleInput, didSelectFeedback sender: Any?) { destinations.append("feedback") }
    func menu(module: MenuModuleInput, didSelectSignIn sender: Any?) { destinations.append("signIn") }
    func menu(module: MenuModuleInput, didSelectOpenConfig sender: Any?) { destinations.append("config") }
    func menu(module: MenuModuleInput, didSelectOpenMyRuuviAccount sender: Any?) { destinations.append("account") }
    func menu(module: MenuModuleInput, didSelectNewsletter url: URL?) {
        destinations.append("newsletter"); newsletter = url
    }
}
