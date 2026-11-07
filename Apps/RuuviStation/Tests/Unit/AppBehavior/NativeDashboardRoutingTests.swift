import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class NativeDashboardRoutingTests: XCTestCase {
    func testExternalLinksKeepTheExactLocalizedDestination() {
        let router = DashboardRouter()
        var opened = [URL]()
        router.openURL = { opened.append($0) }
        let custom = URL(string: "https://ruuvi.com/help?source=station#sensor")!
        router.open(url: custom)
        router.openWhatToMeasurePage()
        router.openRuuviProductsPage()
        router.openRuuviProductsPageFromMenu()
        XCTAssertEqual(
            opened.map(\.absoluteString),
            [
                custom.absoluteString,
                RuuviLocalization.Menu.Measure.Url.ios,
                RuuviLocalization.Ruuvi.BuySensors.Url.ios,
                RuuviLocalization.Ruuvi.BuySensors.Menu.Url.ios,
            ])
    }

    func testRealSignInFlowKeepsBenefitsOnBackAndReportsOfflineOnlyAfterDismissal() async throws {
        let root = UIViewController()
        let host = try AppViewHost(root)
        let app = UIApplication.shared.delegate as? AppDelegate
        let orientation = app?.orientationLock
        defer { host.close(); if let orientation { app?.orientationLock = orientation } }
        let router = DashboardRouter()
        router.transitionHandler = root
        let output = DashboardBenefitsOutput()
        router.openSignIn(output: output)
        await waitForAppState("benefits presented") { root.presentedViewController?.view.window != nil }
        let navigation = try XCTUnwrap(root.presentedViewController as? UINavigationController)
        let benefits = try XCTUnwrap(navigation.topViewController as? SignInBenefitsViewController)
        let presenter = try XCTUnwrap(benefits.output as? SignInBenefitsPresenter)
        XCTAssertTrue(presenter.output === output)
        XCTAssertEqual(app?.orientationLock, .portrait)
        presenter.viewDidTapContinue()
        await waitForAppState("email entry shown") {
            navigation.topViewController is SignInViewController && navigation.transitionCoordinator == nil
        }
        let email = try XCTUnwrap(navigation.topViewController as? SignInViewController)
        let emailPresenter = try XCTUnwrap(email.output as? SignInPresenter)
        XCTAssertFalse(email.viewModel.showVerficationScreen.value ?? true)
        XCTAssertTrue(emailPresenter.output === presenter)
        emailPresenter.viewDidTapBack()
        await waitForAppState("back keeps benefits") { navigation.topViewController === benefits }
        XCTAssertTrue(output.events.isEmpty)
        presenter.viewDidTapContinue()
        await waitForAppState("email entry reopened") {
            navigation.topViewController is SignInViewController && navigation.transitionCoordinator == nil
        }
        let reopened = try XCTUnwrap(navigation.topViewController as? SignInViewController)
        reopened.output.viewDidTapUseWithoutAccount()
        await waitForAppState("offline completes after modal dismissal") {
            root.presentedViewController == nil && output.events == ["offline"]
        }
        XCTAssertTrue(output.module === presenter)
    }

    func testFirmwareRouteForwardsTheSensorAndPreventsDismissalDuringFlashing() async throws {
        let root = UIViewController()
        let host = try AppViewHost(root)
        let measurement = MeasurementFixture()
        defer { host.close(); measurement.cleanup() }
        let router = DashboardRouter()
        router.transitionHandler = root
        let delegate = DashboardDismissDelegate()
        router.delegate = delegate
        let module = DashboardFirmwareModule()
        var ids = [String]()
        router.makeFirmware = { sensor in
            ids.append(sensor.id); return module
        }
        let emptyPresentation = UIPresentationController(presentedViewController: UIViewController(), presenting: root)
        XCTAssertFalse(router.presentationControllerShouldDismiss(emptyPresentation))
        delegate.safe = true
        XCTAssertTrue(router.presentationControllerShouldDismiss(emptyPresentation))
        router.openUpdateFirmware(ruuviTag: measurement.sensor)
        await waitForAppState("firmware presented") { module.viewController.view.window != nil }
        XCTAssertEqual(ids, [measurement.sensor.id])
        XCTAssertTrue(module.output === router)
        let presentation = try XCTUnwrap(module.viewController.presentationController)
        XCTAssertTrue(presentation.delegate === router)
        XCTAssertFalse(router.presentationControllerShouldDismiss(presentation))
        module.safe = true
        XCTAssertTrue(router.presentationControllerShouldDismiss(presentation))
        module.output?.dfuModuleSuccessfullyUpgraded(module)
        await waitForAppState("firmware dismissed") { root.presentedViewController == nil }
    }
}

private final class DashboardBenefitsOutput: SignInBenefitsModuleOutput {
    var events = [String]()
    weak var module: SignInBenefitsModuleInput?
    func signIn(module: SignInBenefitsModuleInput, didCloseSignInWithoutAttempt sender: Any?) {
        events.append("close"); self.module = module
    }
    func signIn(module: SignInBenefitsModuleInput, didSelectUseWithoutAccount sender: Any?) {
        events.append("offline"); self.module = module
    }
    func signIn(module: SignInBenefitsModuleInput, didSuccessfulyLogin sender: Any?) {
        events.append("success"); self.module = module
    }
}
private final class DashboardFirmwareModule: DFUModuleInput {
    let viewController = UIViewController()
    weak var output: DFUModuleOutput?
    var safe = false
    func isSafeToDismiss() -> Bool { safe }
}
private final class DashboardDismissDelegate: DashboardRouterDelegate {
    var safe = false
    func shouldDismissDiscover() -> Bool { safe }
}
