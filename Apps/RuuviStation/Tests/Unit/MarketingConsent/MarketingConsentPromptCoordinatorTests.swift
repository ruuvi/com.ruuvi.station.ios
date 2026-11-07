@testable import station
import RuuviCloud
import RuuviLocal
import RuuviLocalization
import RuuviPresenters
import RuuviService
import RuuviUser
import UIKit
import XCTest

final class MarketingConsentPromptCoordinatorTests: XCTestCase {
    @MainActor func testSuccessfulAndPendingSubscriptionsShowTheCorrectConfirmationAndClose() async throws {
        for status in [RuuviCloudMarketingConsentStatus.subscribed, .unconfirmed] {
            let fixture = Fixture()
            await fixture.showDialog()
            let dialog = try XCTUnwrap(fixture.dialog)
            dialog.onPrimaryAction?()
            await waitForConsentState("subscription save requested") { fixture.service.writes.count == 1 }
            fixture.service.writes[0].resume(returning: .success(.init(consent: status == .subscribed, status: status)))
            await waitForConsentState("subscription confirmation") {
                dialog.view.consentDescendants.compactMap { ($0 as? UILabel)?.text }
                    .contains(RuuviLocalization.marketingConsentPromptSaved)
            }
            let labels = dialog.view.consentDescendants.compactMap { ($0 as? UILabel)?.text }
            XCTAssertEqual(
                labels.contains(RuuviLocalization.newsletterSubscriptionConfirmation), status == .unconfirmed)
            XCTAssertTrue(fixture.buttons(in: dialog).allSatisfy(\.isEnabled))
            XCTAssertNil(dialog.onSecondaryAction)
            dialog.onPrimaryAction?()
            await waitForConsentState("confirmation dismissed") { fixture.dialog == nil }
            XCTAssertEqual(fixture.service.writes.count, 1)
        }
    }

    @MainActor func testRejectedConsentResponseShowsAnErrorAndAllowsRetryWithoutDuplicateWrites() async throws {
        let fixture = Fixture()
        await fixture.showDialog()
        let dialog = try XCTUnwrap(fixture.dialog)
        dialog.onPrimaryAction?()
        await waitForConsentState("first subscription save") { fixture.service.writes.count == 1 }
        fixture.service.writes[0].resume(returning: .success(.init(consent: false, status: .unsubscribed)))
        await waitForConsentState("rejected subscription error") {
            dialog.view.consentDescendants.compactMap { ($0 as? UILabel)?.text }.contains(
                RuuviLocalization.activitySavingFail)
        }
        XCTAssertTrue(fixture.buttons(in: dialog).allSatisfy(\.isEnabled))
        dialog.onPrimaryAction?()
        dialog.onPrimaryAction?()
        await waitForConsentState("subscription retry") { fixture.service.writes.count == 2 }
        fixture.service.writes[1].resume(returning: .failure(.failedToParseNetworkResponse))
        await fixture.settle()
        XCTAssertTrue(fixture.buttons(in: dialog).allSatisfy(\.isEnabled))
        await fixture.dismiss()
    }

    @MainActor func testChangingAccountWhileSavingCannotShowThePreviousAccountsConfirmation() async throws {
        let fixture = Fixture()
        await fixture.showDialog()
        let dialog = try XCTUnwrap(fixture.dialog)
        dialog.onPrimaryAction?()
        await waitForConsentState("subscription save pending") { fixture.service.writes.count == 1 }
        fixture.user.apiKey = "replacement-session"
        fixture.user.email = "replacement@example.com"
        fixture.service.writes[0].resume(returning: .success(.init(consent: true, status: .subscribed)))
        await waitForConsentState("stale subscription dialog dismissed") { fixture.dialog == nil }
        XCTAssertTrue(fixture.history.isEligible(account: "replacement@example.com"))
    }

    @MainActor func testPendingConsentCheckDoesNotRetainCoordinator() async {
        let fixture = Fixture()
        var coordinator: MarketingConsentPromptCoordinator? = MarketingConsentPromptCoordinator(
            history: fixture.history, user: fixture.user, service: fixture.service, flags: fixture.flags)
        weak var releasedCoordinator = coordinator
        coordinator?.presentIfNeeded(from: fixture.presenter)
        await fixture.settle()
        XCTAssertEqual(fixture.service.reads.count, 1)
        coordinator = nil
        XCTAssertNil(releasedCoordinator, "A pending request must not keep the screen coordinator alive")
        fixture.service.reads[0].resume(returning: .success(.init(consent: false, status: .notFound)))
        await fixture.settle()
        XCTAssertNil(fixture.dialog)
    }

    @MainActor func testPendingConsentCheckDoesNotRetainPresentingScreen() async {
        let fixture = Fixture()
        var presenter: UIViewController? = UIViewController()
        weak var releasedPresenter = presenter
        fixture.window.rootViewController = presenter
        presenter?.view.layoutIfNeeded()
        fixture.coordinator.presentIfNeeded(from: presenter!)
        await fixture.settle()
        XCTAssertEqual(fixture.service.reads.count, 1)
        fixture.window.rootViewController = fixture.presenter
        presenter = nil
        await fixture.settle()
        XCTAssertNil(releasedPresenter, "A pending request must not retain a dismissed screen")
        fixture.service.reads[0].resume(returning: .success(.init(consent: false, status: .notFound)))
        await fixture.settle()
        XCTAssertNil(fixture.dialog)
    }

    @MainActor func testNewSessionDoesNotWaitForOrUseOldConsentCheck() async {
        let fixture = Fixture()
        await fixture.check()
        fixture.user.apiKey = "second-session"
        fixture.user.email = "second@example.com"
        await fixture.check()
        XCTAssertEqual(fixture.service.reads.count, 2)
        fixture.service.reads[0].resume(returning: .success(.init(consent: false, status: .notFound)))
        await fixture.settle()
        XCTAssertNil(fixture.dialog)
        await fixture.check()
        XCTAssertEqual(fixture.service.reads.count, 2, "Old response must not clear the newer request")
        fixture.service.reads[1].resume(returning: .success(.init(consent: false, status: .unsubscribed)))
        await fixture.settle()
        XCTAssertNotNil(fixture.dialog)
        XCTAssertTrue(fixture.history.isEligible(account: "first@example.com"))
        XCTAssertFalse(fixture.history.isEligible(account: "second@example.com"))
        await fixture.dismiss()
    }

    @MainActor func testDismissedSaveDoesNotBlockNextDialogOrCompleteItsSave() async {
        let fixture = Fixture()
        await fixture.showDialog()
        let first = fixture.dialog
        first?.onPrimaryAction?()
        first?.onPrimaryAction?()
        await fixture.settle()
        XCTAssertEqual(fixture.service.writes.count, 1, "Duplicate taps must not issue another save")
        await fixture.dismiss()
        fixture.history.markPresented(account: "first@example.com", now: Date().addingTimeInterval(-61))
        await fixture.showDialog()
        let second = fixture.dialog
        XCTAssertNotNil(second)
        XCTAssertFalse(first === second)
        second?.onPrimaryAction?()
        await fixture.settle()
        XCTAssertEqual(fixture.service.writes.count, 2)
        guard fixture.service.writes.count == 2 else { return }
        fixture.service.writes[0].resume(returning: .success(.init(consent: true, status: .subscribed)))
        await fixture.settle()
        XCTAssertTrue(fixture.buttons(in: second).allSatisfy { !$0.isEnabled })
        fixture.service.writes[1].resume(returning: .failure(.failedToParseNetworkResponse))
        await fixture.settle()
        XCTAssertTrue(fixture.buttons(in: second).allSatisfy(\.isEnabled))
        await fixture.dismiss()
    }

    @MainActor func testSubscribedAndUnavailableStatusesNeverPresent() async {
        for status in [RuuviCloudMarketingConsentStatus.subscribed, .unconfirmed, .bounced, .softBounced, .complained] {
            let fixture = Fixture()
            await fixture.check()
            fixture.service.reads[0].resume(returning: .success(.init(consent: false, status: status)))
            await fixture.settle()
            XCTAssertNil(fixture.dialog, status.rawValue)
            XCTAssertTrue(fixture.history.isEligible(account: "first@example.com"))
        }
        let fixture = Fixture()
        await fixture.check()
        fixture.service.reads[0].resume(returning: .success(.init(consent: true, status: .unsubscribed)))
        await fixture.settle()
        XCTAssertNil(fixture.dialog)
    }

    @MainActor func testFailureCanRetryWithoutStartingCooldown() async {
        let fixture = Fixture()
        await fixture.check()
        fixture.service.reads[0].resume(returning: .failure(.failedToParseNetworkResponse))
        await fixture.settle()
        XCTAssertTrue(fixture.history.isEligible(account: "first@example.com"))
        await fixture.showDialog()
        XCTAssertEqual(fixture.service.reads.count, 2)
        XCTAssertNotNil(fixture.dialog)
        await fixture.dismiss()
    }

    @MainActor func testDisabledFlagCannotSubscribe() async {
        let fixture = Fixture()
        await fixture.showDialog()
        fixture.flags.showMarketingPreference = false
        fixture.dialog?.onPrimaryAction?()
        await fixture.settle()
        XCTAssertTrue(fixture.service.writes.isEmpty)
        XCTAssertNil(fixture.dialog)
    }

    @MainActor func testSignOutCannotSubscribe() async {
        let fixture = Fixture()
        await fixture.showDialog()
        fixture.user.logout()
        fixture.dialog?.onPrimaryAction?()
        await fixture.settle()
        XCTAssertTrue(fixture.service.writes.isEmpty)
        XCTAssertNil(fixture.dialog)
    }
}

@MainActor private final class ConsentService: RuuviServiceMarketingConsent {
    typealias Response = CheckedContinuation<Result<RuuviCloudMarketingConsent, RuuviServiceError>, Never>
    var reads = [Response]()
    var writes = [Response]()
    func getMarketingConsent() async throws(RuuviServiceError) -> RuuviCloudMarketingConsent {
        let result = await withCheckedContinuation { reads.append($0) }
        return try result.get()
    }
    func set(marketingPreference: Bool) async throws(RuuviServiceError) -> RuuviCloudMarketingConsent {
        XCTAssertTrue(marketingPreference)
        let result = await withCheckedContinuation { writes.append($0) }
        return try result.get()
    }
}

private final class ConsentUser: RuuviUser {
    var email: String? = "first@example.com"
    var apiKey: String? = "first-session"
    var isAuthorized: Bool { apiKey != nil }
    func login(apiKey: String) { self.apiKey = apiKey }
    func logout() { email = nil; apiKey = nil }
}

private final class ConsentFlags: RuuviLocalFlags {
    var showNewSettings = false
    var downloadBetaFirmware = false
    var downloadAlphaFirmware = false
    var autoSyncGattHistoryForRuuviAir = true
    var autoSyncGattHistoryForRuuviAirMinimumLastSyncDateAgeMinutes = 5
    var allowConcurrentGattSyncForMultipleSensors = true
    var showMarketingPreference = true
    var marketingConsentPromptIntervalMinutes = 1
    var showDashboardSensorSearch = false
    var graphDownsampleMaximumPoints = 3000
}

@MainActor private final class Fixture {
    let suite = "MarketingConsentPromptCoordinatorTests.\(UUID().uuidString)"
    let history: MarketingConsentPromptHistory
    let user = ConsentUser()
    let flags = ConsentFlags()
    let service = ConsentService()
    let presenter = UIViewController()
    let window: UIWindow
    let coordinator: MarketingConsentPromptCoordinator

    init() {
        history = MarketingConsentPromptHistory(defaults: UserDefaults(suiteName: suite)!)
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        coordinator = MarketingConsentPromptCoordinator(history: history, user: user, service: service, flags: flags)
        window.windowLevel = .alert + 1
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        presenter.view.layoutIfNeeded()
        UIView.setAnimationsEnabled(false)
    }

    deinit {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    var dialog: RuuviDialogViewController? { presenter.presentedViewController as? RuuviDialogViewController }
    func check() async { coordinator.presentIfNeeded(from: presenter); await settle() }
    func settle() async { try? await Task.sleep(nanoseconds: 150_000_000) }
    func showDialog() async {
        await check()
        service.reads.last?.resume(returning: .success(.init(consent: false, status: .notFound)))
        await settle()
    }
    func dismiss() async {
        presenter.dismiss(animated: false)
        await settle()
    }
    func buttons(in dialog: RuuviDialogViewController?) -> [UIButton] {
        func collect(_ view: UIView) -> [UIButton] {
            view.subviews.flatMap { ($0 as? UIButton).map { [$0] } ?? collect($0) }
        }
        return dialog.map { collect($0.view) } ?? []
    }
}

@MainActor private func waitForConsentState(
    _ description: String, file: StaticString = #filePath, line: UInt = #line,
    _ condition: () -> Bool
) async {
    for _ in 0..<200 {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Timed out waiting for " + description, file: file, line: line)
}
private extension UIView {
    var consentDescendants: [UIView] { subviews.flatMap { [$0] + $0.consentDescendants } }
}
