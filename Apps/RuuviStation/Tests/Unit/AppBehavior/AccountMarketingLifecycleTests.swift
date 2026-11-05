import Foundation
import RuuviCloud
import RuuviService
import XCTest
@testable import station

@MainActor final class AccountMarketingLifecycleTests: XCTestCase {
    func testConfirmedSubscribeAndUnsubscribeResponsesRestoreEditingWithoutAConfirmationDialog() async {
        for (enabled, status): (Bool, RuuviCloudMarketingConsentStatus) in [
            (true, .subscribed), (false, .unsubscribed),
        ] {
            let fixture = AccountFixture()
            fixture.settings.marketingPreference = !enabled
            fixture.appSettings.onSetMarketing = { value in .init(consent: value, status: status) }
            fixture.presenter.viewDidChangeMarketingPreference(isEnabled: enabled)
            await waitForAppState("confirmed preference") { fixture.activity.dismissals.count == 1 }
            XCTAssertEqual(fixture.settings.marketingPreference, enabled)
            XCTAssertEqual(fixture.view.viewModel?.marketingPreference.value, enabled)
            XCTAssertEqual(fixture.view.viewModel?.marketingPreferenceEnabled.value, true)
            XCTAssertNil(fixture.view.viewModel?.marketingPreferenceStatusMessage.value)
            XCTAssertEqual(fixture.view.confirmations, 0)
        }
    }

    func testLateConsentReadCannotReplaceANewerSavedPreference() async {
        let fixture = AccountFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.appSettings.onGetMarketing = {
            await withCheckedContinuation { release = $0 }
            return .init(consent: false, status: .unsubscribed)
        }
        fixture.appSettings.onSetMarketing = { _ in .init(consent: true, status: .subscribed) }
        fixture.presenter.viewDidLoad()
        await waitForAppState("consent read pending") { release != nil }
        fixture.presenter.viewDidChangeMarketingPreference(isEnabled: true)
        await waitForAppState("new preference saved") { fixture.activity.dismissals.count == 1 }
        release?.resume(); release = nil
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.settings.marketingPreference)
        XCTAssertEqual(fixture.view.viewModel?.marketingPreference.value, true)
        XCTAssertEqual(fixture.view.viewModel?.marketingPreferenceEnabled.value, true)
    }

    func testClosingDuringConsentSaveReleasesThePresenterAndDismissesActivity() async {
        let fixture = AccountFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.appSettings.onSetMarketing = { _ in
            await withCheckedContinuation { release = $0 }
            return .init(consent: true, status: .unconfirmed)
        }
        fixture.presenter.viewDidChangeMarketingPreference(isEnabled: true)
        await waitForAppState("consent save pending") { release != nil }
        weak var presenter = fixture.presenter
        fixture.presenter = nil
        XCTAssertNil(presenter)
        release?.resume(); release = nil
        await waitForAppState("consent activity dismissed") { fixture.activity.dismissals.count == 1 }
        XCTAssertEqual(fixture.view.confirmations, 0)
    }

    func testConsentRefreshFailurePreservesTheCachedPreference() async {
        let fixture = AccountFixture()
        fixture.settings.marketingPreference = true
        fixture.appSettings.onGetMarketing = { () async throws(RuuviServiceError) -> RuuviCloudMarketingConsent in
            throw .failedToParseNetworkResponse
        }
        fixture.presenter.viewDidLoad()
        await waitForAppState("consent request") { fixture.appSettings.calls == ["getMarketing"] }
        await flushAppBindings()
        XCTAssertTrue(fixture.settings.marketingPreference)
        XCTAssertEqual(fixture.view.viewModel?.marketingPreference.value, true)
        XCTAssertTrue(fixture.errors.errors.isEmpty)
        XCTAssertTrue(fixture.activity.shown.isEmpty)
    }
}
