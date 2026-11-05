import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class AccountViewTests: XCTestCase {
    func testAnAccountModelAssignedBeforeLoadingAppearsWhenTheViewOpens() async throws {
        let (view, output) = try controller()
        let model = MyRuuviAccountViewModel()
        model.username.value = "owner@example.com"
        model.showMarketingPreference.value = true
        model.marketingPreference.value = true
        model.marketingPreferenceEnabled.value = true
        view.viewModel = model
        view.loadViewIfNeeded()
        await flushAppBindings()
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(view.usernameLabel.text, "owner@example.com")
        XCTAssertEqual(view.loggedInLabel.text, RuuviLocalization.Menu.LoggedIn.title)
        let toggle = try XCTUnwrap(view.view.allDescendants.compactMap { $0 as? RuuviSwitchView }.first)
        XCTAssertTrue(toggle.isOn())
        XCTAssertTrue(toggle.isEditable())
    }

    func testAccountControlsAndConsentBindingsWorkInBothThemes() async throws {
        for theme: UIUserInterfaceStyle in [.light, .dark] {
            let (view, output) = try controller()
            view.overrideUserInterfaceStyle = theme
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 700))
            window.rootViewController = view
            defer { window.rootViewController = nil }
            view.loadViewIfNeeded()
            view.view.frame = window.bounds
            let model = MyRuuviAccountViewModel()
            model.username.value = "owner@example.com"
            model.showMarketingPreference.value = true
            model.marketingPreference.value = true
            model.marketingPreferenceEnabled.value = true
            model.marketingPreferenceStatusMessage.value = "Please confirm your subscription"
            view.viewModel = model
            await flushAppBindings()
            view.view.layoutIfNeeded()
            XCTAssertEqual(view.title, RuuviLocalization.Menu.Label.MyRuuviAccount.text)
            XCTAssertEqual(view.usernameLabel.text, "owner@example.com")
            XCTAssertEqual(
                view.deleteAccountButton.title(for: .normal), RuuviLocalization.MyRuuvi.Settings.DeleteAccount.title)
            XCTAssertEqual(view.signoutButton.title(for: .normal), RuuviLocalization.Menu.SignOut.text)
            let toggle = try XCTUnwrap(view.view.allDescendants.compactMap { $0 as? RuuviSwitchView }.first)
            XCTAssertTrue(toggle.isOn())
            XCTAssertTrue(toggle.isEditable())
            let labels = view.view.allDescendants.compactMap { $0 as? UILabel }
            let status = try XCTUnwrap(labels.first { $0.text == "Please confirm your subscription" })
            XCTAssertFalse(status.isHidden)
            let scroll = try XCTUnwrap(view.view.allDescendants.compactMap { $0 as? UIScrollView }.first)
            let buttonFrame = view.deleteAccountButton.convert(view.deleteAccountButton.bounds, to: view.view)
            XCTAssertGreaterThanOrEqual(buttonFrame.minY, scroll.frame.maxY)
            XCTAssertLessThanOrEqual(buttonFrame.maxY, view.view.bounds.maxY)
            view.deleteAccountButton.sendActions(for: .touchUpInside)
            view.signoutButton.sendActions(for: .touchUpInside)
            view.backButtonTouchUpInside(self)
            view.didTapLink(url: "support@example.com")
            view.didChangeSwitchState(sender: toggle, didToggle: false)
            XCTAssertEqual(output.deletions, 1)
            XCTAssertEqual(output.signouts, 1)
            XCTAssertEqual(output.closes, 1)
            XCTAssertEqual(output.support, ["support@example.com"])
            XCTAssertEqual(output.preferences, [false])
            model.username.value = nil
            model.marketingPreference.value = false
            model.marketingPreferenceEnabled.value = false
            model.marketingPreferenceStatusMessage.value = nil
            await flushAppBindings()
            XCTAssertNil(view.usernameLabel.text)
            XCTAssertNil(view.loggedInLabel.text)
            XCTAssertFalse(toggle.isOn())
            XCTAssertFalse(toggle.isEditable())
            XCTAssertTrue(status.isHidden)
        }
    }

    func testAccountAndNewsletterConfirmationDialogsHaveClearDismissalActions() async throws {
        let (view, _) = try controller()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = view
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKeyAndVisible() }
        let checks: [(String, String?, () -> Void)] = [
            (
                RuuviLocalization.MyRuuvi.Settings.DeleteAccount.Confirmation.message, nil,
                {
                    view.viewDidShowAccountDeletionConfirmation()
                }
            ),
            (
                RuuviLocalization.newsletterSubscription, RuuviLocalization.newsletterSubscriptionConfirmation,
                {
                    view.viewDidReceiveUnconfirmedMarketingConsent()
                }
            ),
        ]
        for (title, message, show) in checks {
            show()
            let alert = try XCTUnwrap(view.presentedViewController as? UIAlertController)
            XCTAssertEqual(alert.title, title)
            XCTAssertEqual(alert.message, message)
            XCTAssertEqual(alert.actions.map(\.title), [RuuviLocalization.ok])
            XCTAssertEqual(alert.actions.first?.style, .cancel)
            await waitForAppState("account alert presented") { !alert.isBeingPresented }
            await withCheckedContinuation { continuation in
                view.dismiss(animated: false) { continuation.resume() }
            }
        }
    }

    private func controller() throws -> (MyRuuviAccountViewController, AccountViewOutputSpy) {
        let view = try XCTUnwrap(
            UIStoryboard(name: "MyRuuvi", bundle: .main)
                .instantiateViewController(withIdentifier: "MyRuuviAccountViewController")
                as? MyRuuviAccountViewController)
        let output = AccountViewOutputSpy()
        view.output = output
        return (view, output)
    }
}

private final class AccountViewOutputSpy: MyRuuviAccountViewOutput {
    var loads = 0
    var deletions = 0
    var signouts = 0
    var closes = 0
    var support = [String]()
    var preferences = [Bool]()
    func viewDidLoad() { loads += 1 }
    func viewDidTapDeleteButton() { deletions += 1 }
    func viewDidTapSignoutButton() { signouts += 1 }
    func viewDidTriggerClose() { closes += 1 }
    func viewDidTriggerSupport(with email: String) { support.append(email) }
    func viewDidChangeMarketingPreference(isEnabled: Bool) { preferences.append(isEnabled) }
}
