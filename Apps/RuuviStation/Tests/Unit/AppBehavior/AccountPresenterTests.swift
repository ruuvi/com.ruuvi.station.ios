import RuuviCloud
import RuuviLocalization
import RuuviService
import XCTest
@testable import station

@MainActor final class AccountPresenterTests: XCTestCase {
    func testAccountIdentityAndEveryMarketingStatusControlTheNewsletterSwitch() async {
        for status: RuuviCloudMarketingConsentStatus in [
            .subscribed, .unsubscribed, .unconfirmed, .bounced, .softBounced, .complained, .notFound,
        ] {
            let fixture = AccountFixture()
            fixture.appSettings.onGetMarketing = { .init(consent: true, status: status) }
            fixture.presenter.viewDidLoad()
            await waitForAppState("marketing status loaded") {
                fixture.view.viewModel?.marketingPreference.value == true
            }
            XCTAssertEqual(fixture.view.viewModel?.username.value, "owner@example.com")
            XCTAssertEqual(fixture.view.viewModel?.showMarketingPreference.value, true)
            XCTAssertEqual(
                fixture.view.viewModel?.marketingPreferenceEnabled.value,
                [.subscribed, .unsubscribed, .notFound].contains(status))
            XCTAssertEqual(
                fixture.view.viewModel?.marketingPreferenceStatusMessage.value,
                status == .unconfirmed ? RuuviLocalization.newsletterSubscriptionConfirmation : nil)
            XCTAssertTrue(fixture.settings.marketingPreference)
        }
    }

    func testHiddenMarketingAndSignedOutAccountsDoNotFetchConsent() async {
        for authorized in [true, false] {
            let fixture = AccountFixture()
            fixture.user.isAuthorized = authorized
            fixture.flags.showMarketingPreference = !authorized
            fixture.presenter.viewDidLoad()
            await flushAppBindings()
            XCTAssertTrue(fixture.appSettings.calls.isEmpty)
            XCTAssertEqual(fixture.view.viewModel?.username.value, authorized ? "owner@example.com" : nil)
            XCTAssertEqual(fixture.view.viewModel?.showMarketingPreference.value, !authorized)
        }
    }

    func testSavingUnconfirmedConsentShowsInstructionsAndDismissesActivityOnce() async {
        let fixture = AccountFixture()
        fixture.appSettings.onSetMarketing = { enabled in .init(consent: enabled, status: .unconfirmed) }
        fixture.presenter.viewDidChangeMarketingPreference(isEnabled: true)
        XCTAssertEqual(fixture.view.viewModel?.marketingPreference.value, true)
        XCTAssertEqual(fixture.view.viewModel?.marketingPreferenceEnabled.value, false)
        await waitForAppState("newsletter confirmation") { fixture.view.confirmations == 1 }
        XCTAssertTrue(fixture.settings.marketingPreference)
        XCTAssertEqual(fixture.activity.shown, [.loading(message: nil)])
        XCTAssertEqual(fixture.activity.updates, [.success(message: nil)])
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
        XCTAssertEqual(
            fixture.view.viewModel?.marketingPreferenceStatusMessage.value,
            RuuviLocalization.newsletterSubscriptionConfirmation)
    }

    func testFailedPreferenceChangeRestoresThePreviouslyConfirmedPreference() async {
        let fixture = AccountFixture()
        fixture.appSettings.onGetMarketing = { .init(consent: true, status: .subscribed) }
        fixture.presenter.viewDidLoad()
        await waitForAppState("subscribed status") { fixture.view.viewModel?.marketingPreference.value == true }
        fixture.appSettings.onSetMarketing = {
            (_: Bool) async throws(RuuviServiceError) -> RuuviCloudMarketingConsent in
            throw .failedToParseNetworkResponse
        }
        fixture.presenter.viewDidChangeMarketingPreference(isEnabled: false)
        await waitForAppState("preference failure") { fixture.errors.errors.count == 1 }
        XCTAssertTrue(fixture.settings.marketingPreference)
        XCTAssertEqual(fixture.view.viewModel?.marketingPreference.value, true)
        XCTAssertEqual(fixture.view.viewModel?.marketingPreferenceEnabled.value, true)
        XCTAssertEqual(fixture.activity.updates, [.failed(message: nil)])
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
    }

    func testAccountDeletionUsesNormalizedEmailAndReportsSuccessAndFailure() async {
        let fixture = AccountFixture()
        fixture.cloud.onDeleteAccount = { _ in true }
        fixture.presenter.viewDidTapDeleteButton()
        await waitForAppState("deletion confirmation") { fixture.view.deletions == 1 }
        XCTAssertEqual(fixture.cloud.deletedEmails, ["owner@example.com"])
        XCTAssertEqual(fixture.activity.updates.last, .success(message: nil))
        fixture.cloud.onDeleteAccount = { (_: String) async throws(RuuviCloudError) -> Bool in
            throw .notAuthorized
        }
        fixture.presenter.viewDidTapDeleteButton()
        await waitForAppState("deletion failure") { fixture.errors.errors.count == 1 }
        XCTAssertEqual(fixture.view.deletions, 1)
        XCTAssertEqual(fixture.activity.dismissals.count, 2)
        XCTAssertEqual(fixture.activity.updates.last, .failed(message: nil))
        fixture.user.email = nil
        fixture.presenter.viewDidTapDeleteButton()
        await flushAppBindings()
        XCTAssertEqual(fixture.cloud.deletedEmails.count, 2)
    }

    func testCloseSupportAndSignOutConfirmationDoNotModifyTheAccount() {
        let fixture = AccountFixture()
        fixture.presenter.viewDidTriggerSupport(with: "SUPPORT@EXAMPLE.COM")
        XCTAssertEqual(fixture.mail.emails, ["support@example.com"])
        fixture.presenter.viewDidTapSignoutButton()
        XCTAssertEqual(fixture.alerts.alerts.count, 1)
        XCTAssertEqual(fixture.alerts.alerts.first?.title, RuuviLocalization.Menu.SignOut.text)
        XCTAssertEqual(fixture.alerts.alerts.first?.actions.map(\.style), [.default, .cancel])
        XCTAssertEqual(fixture.auth.calls, 0)
        fixture.presenter.viewDidTriggerClose()
        XCTAssertEqual(fixture.router.dismissals, 1)
    }
}
