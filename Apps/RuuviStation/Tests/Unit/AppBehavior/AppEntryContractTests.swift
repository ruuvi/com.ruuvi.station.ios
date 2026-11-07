import RuuviAnalytics
import RuuviOnboard
import UIKit
import XCTest
@testable import station

@MainActor final class AppEntryContractTests: XCTestCase {
    func testInitialDashboardRequiresAllThreeCompletedOnboardingFlags() throws {
        let delegate = UIApplication.shared.delegate as? AppDelegate
        let orientation = delegate?.orientationLock
        defer { if let orientation { delegate?.orientationLock = orientation } }
        for mask in 0..<8 {
            let settings = AppTestSettings()
            settings.welcomeShown = mask & 1 != 0
            settings.tosAccepted = mask & 2 != 0
            settings.analyticsConsentGiven = mask & 4 != 0
            let router = AppRouter()
            router.settings = settings
            let dashboard = UIViewController()
            let onboarding = UIViewController()
            var dashboardCreations = 0
            var onboardingCreations = 0
            router.makeDashboard = {
                dashboardCreations += 1; return dashboard
            }
            router.makeOnboarding = { [weak router] child in
                XCTAssertTrue(child.delegate === router)
                onboardingCreations += 1
                return onboarding
            }
            let navigation = try XCTUnwrap(router.viewController as? UINavigationController)
            XCTAssertTrue(router.viewController === navigation)
            XCTAssertTrue(navigation.viewControllers.first === (mask == 7 ? dashboard : onboarding))
            XCTAssertEqual(dashboardCreations, mask == 7 ? 1 : 0)
            XCTAssertEqual(onboardingCreations, mask == 7 ? 0 : 1)
            XCTAssertEqual(navigation.viewControllers.count, 1)
        }
    }

    func testFinishingOnboardingRecordsCompletionAndHonorsActualAnalyticsConsent() async throws {
        let delegate = UIApplication.shared.delegate as? AppDelegate
        let orientation = delegate?.orientationLock
        defer { if let orientation { delegate?.orientationLock = orientation } }
        for consent in [false, true] {
            let router = AppRouter()
            let settings = AppTestSettings()
            let analytics = EntryAnalyticsSpy()
            let dashboard = UIViewController()
            let onboarding = UIViewController()
            router.settings = settings
            router.ruuviAnalytics = analytics
            router.makeDashboard = { dashboard }
            router.makeOnboarding = { _ in onboarding }
            let navigation = try XCTUnwrap(router.viewController as? UINavigationController)
            let host = try AppEntryWindow(navigation)
            defer { host.close() }
            await waitForAppState("onboarding navigation attached") { onboarding.view.window === host.window }
            let child = OnboardRouter()
            router.ruuviOnboardDidProvideAnalyticsConsent(child, consentGiven: consent)
            XCTAssertTrue(analytics.consents.isEmpty)
            router.onboardRouterDidFinish(child)
            await waitForAppState("dashboard replaced onboarding") {
                navigation.topViewController === dashboard && navigation.viewControllers.count == 1
            }
            XCTAssertEqual(analytics.consents, [consent])
            XCTAssertTrue(settings.welcomeShown)
            XCTAssertTrue(settings.tosAccepted)
            XCTAssertTrue(settings.analyticsConsentGiven, "This flag records that the consent step was completed")
            XCTAssertTrue(navigation.viewControllers.first === dashboard)
            XCTAssertEqual(navigation.viewControllers.count, 1)
            XCTAssertFalse(navigation.isNavigationBarHidden)
            XCTAssertEqual(delegate?.orientationLock, .all)
        }
    }

    func testClosingSignInKeepsOnboardingAndOfflineCompletionWaitsUntilTheSheetDismisses() async throws {
        let delegate = UIApplication.shared.delegate as? AppDelegate
        let orientation = delegate?.orientationLock
        defer { if let orientation { delegate?.orientationLock = orientation } }
        let router = AppRouter()
        let settings = AppTestSettings()
        let analytics = EntryAnalyticsSpy()
        let dashboard = UIViewController()
        let onboarding = UIViewController()
        router.settings = settings
        router.ruuviAnalytics = analytics
        router.makeDashboard = { dashboard }
        router.makeOnboarding = { _ in onboarding }
        let navigation = try XCTUnwrap(router.viewController as? UINavigationController)
        let host = try AppEntryWindow(navigation)
        defer { host.close() }
        await waitForAppState("onboarding navigation attached") { onboarding.view.window === host.window }
        let child = OnboardRouter()
        let signIn = EntryBenefitsSpy()
        router.onboardRouterDidFinish(child, module: signIn, showDashboard: false)
        XCTAssertEqual(signIn.dismissals, 1)
        signIn.finish?()
        XCTAssertTrue(navigation.viewControllers.first === onboarding)
        XCTAssertFalse(settings.welcomeShown)
        XCTAssertTrue(analytics.consents.isEmpty)
        router.onboardRouterDidFinish(child, module: signIn, showDashboard: true)
        XCTAssertEqual(signIn.dismissals, 2)
        XCTAssertTrue(navigation.viewControllers.first === onboarding)
        signIn.finish?()
        await waitForAppState("offline completion opened dashboard") {
            navigation.topViewController === dashboard && navigation.viewControllers.count == 1
        }
        XCTAssertTrue(navigation.viewControllers.first === dashboard)
        XCTAssertEqual(analytics.consents, [false])
    }

    func testOnboardingForwardsDistinctCloseLoginOfflineAndConsentEvents() {
        let router = OnboardRouter()
        let delegate = EntryOnboardDelegateSpy()
        router.delegate = delegate
        let onboarding = EntryOnboardingSpy()
        let signIn = EntryBenefitsSpy()
        router.ruuviOnboardDidFinish(onboarding)
        router.ruuviOnboardDidShowSignIn(onboarding)
        router.ruuviOnboardDidProvideAnalyticsConsent(onboarding, consentGiven: false)
        router.signIn(module: signIn, didCloseSignInWithoutAttempt: nil)
        router.signIn(module: signIn, didSelectUseWithoutAccount: nil)
        router.signIn(module: signIn, didSuccessfulyLogin: nil)
        XCTAssertEqual(delegate.finishes, 1)
        XCTAssertTrue(delegate.signInOutput === router)
        XCTAssertEqual(delegate.consents, [false])
        XCTAssertEqual(delegate.dashboardChoices, [false, true, true])
        XCTAssertTrue(delegate.module === signIn)
    }
}
private final class EntryAnalyticsSpy: RuuviAnalytics {
    var consents = [Bool]()
    func update() { XCTFail("Finishing onboarding should only set consent") }
    func setConsent(allowed: Bool) { consents.append(allowed) }
}
private final class EntryBenefitsSpy: SignInBenefitsModuleInput {
    var dismissals = 0
    var finish: (() -> Void)?
    func configure(output: SignInBenefitsModuleOutput?) {}
    func dismiss(completion: (() -> Void)?) { dismissals += 1; finish = completion }
}
private final class EntryOnboardingSpy: RuuviOnboard {
    let viewController = UIViewController()
    var router: AnyObject?
}
private final class EntryOnboardDelegateSpy: OnboardRouterDelegate {
    var finishes = 0
    weak var signInOutput: SignInBenefitsModuleOutput?
    var consents = [Bool]()
    var dashboardChoices = [Bool]()
    weak var module: SignInBenefitsModuleInput?
    func onboardRouterDidFinish(_ router: OnboardRouter) { finishes += 1 }
    func onboardRouterDidFinish(_ router: OnboardRouter, module: SignInBenefitsModuleInput, showDashboard: Bool) {
        self.module = module; dashboardChoices.append(showDashboard)
    }
    func onboardRouterDidShowSignIn(_ router: OnboardRouter, output: SignInBenefitsModuleOutput) {
        signInOutput = output
    }
    func ruuviOnboardDidProvideAnalyticsConsent(_ router: OnboardRouter, consentGiven: Bool) {
        consents.append(consentGiven)
    }
}

@MainActor private final class AppEntryWindow {
    let window: UIWindow
    private let previous: UIWindow?
    private let animationsEnabled = UIView.areAnimationsEnabled
    init(_ navigation: UINavigationController) throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.delegate is SceneDelegate })
        previous = scene.windows.first(where: \.isKeyWindow)
        UIView.setAnimationsEnabled(false)
        window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
    }
    func close() {
        window.isHidden = true
        window.rootViewController = nil
        previous?.makeKeyAndVisible()
        UIView.setAnimationsEnabled(animationsEnabled)
    }
}
