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
            let fixture = try await Fixture()
            defer { fixture.close() }
            try await fixture.showDialog()
            let dialog = try XCTUnwrap(fixture.dialog)
            dialog.onPrimaryAction?()
            try await waitForConsentState("subscription save requested") { fixture.service.writes.count == 1 }
            try XCTUnwrap(fixture.service.writes.first).resume(
                returning: .success(.init(consent: status == .subscribed, status: status)))
            try await waitForConsentState("subscription confirmation") {
                dialog.view.consentDescendants.compactMap { ($0 as? UILabel)?.text }
                    .contains(RuuviLocalization.marketingConsentPromptSaved)
            }
            let labels = dialog.view.consentDescendants.compactMap { ($0 as? UILabel)?.text }
            XCTAssertEqual(
                labels.contains(RuuviLocalization.newsletterSubscriptionConfirmation), status == .unconfirmed)
            XCTAssertTrue(fixture.buttons(in: dialog).allSatisfy(\.isEnabled))
            XCTAssertNil(dialog.onSecondaryAction)
            dialog.onPrimaryAction?()
            try await waitForConsentState("confirmation dismissed") { fixture.dialog == nil }
            XCTAssertEqual(fixture.service.writes.count, 1)
        }
    }

    @MainActor func testRejectedConsentResponseShowsAnErrorAndAllowsRetryWithoutDuplicateWrites() async throws {
        let fixture = try await Fixture()
        defer { fixture.close() }
        try await fixture.showDialog()
        let dialog = try XCTUnwrap(fixture.dialog)
        dialog.onPrimaryAction?()
        try await waitForConsentState("first subscription save") { fixture.service.writes.count == 1 }
        try XCTUnwrap(fixture.service.writes.first).resume(
            returning: .success(.init(consent: false, status: .unsubscribed)))
        try await waitForConsentState("rejected subscription error") {
            dialog.view.consentDescendants.compactMap { ($0 as? UILabel)?.text }.contains(
                RuuviLocalization.activitySavingFail)
        }
        XCTAssertTrue(fixture.buttons(in: dialog).allSatisfy(\.isEnabled))
        dialog.onPrimaryAction?()
        dialog.onPrimaryAction?()
        try await waitForConsentState("subscription retry") { fixture.service.writes.count == 2 }
        try XCTUnwrap(fixture.service.writes.dropFirst().first).resume(
            returning: .failure(.failedToParseNetworkResponse))
        await fixture.settle()
        XCTAssertTrue(fixture.buttons(in: dialog).allSatisfy(\.isEnabled))
        try await fixture.dismiss()
    }

    @MainActor func testChangingAccountWhileSavingCannotShowThePreviousAccountsConfirmation() async throws {
        let fixture = try await Fixture()
        defer { fixture.close() }
        try await fixture.showDialog()
        let dialog = try XCTUnwrap(fixture.dialog)
        dialog.onPrimaryAction?()
        try await waitForConsentState("subscription save pending") { fixture.service.writes.count == 1 }
        fixture.user.apiKey = "replacement-session"
        fixture.user.email = "replacement@example.com"
        try XCTUnwrap(fixture.service.writes.first).resume(
            returning: .success(.init(consent: true, status: .subscribed)))
        try await waitForConsentState("stale subscription dialog dismissed") { fixture.dialog == nil }
        XCTAssertTrue(fixture.history.isEligible(account: "replacement@example.com"))
    }

    @MainActor func testDetachedPresenterDoesNotStartAConsentCheckOrCooldown() async throws {
        let fixture = try await Fixture()
        defer { fixture.close() }
        let detached = UIViewController()
        detached.loadViewIfNeeded()
        fixture.coordinator.presentIfNeeded(from: detached)
        await fixture.settle()
        XCTAssertTrue(fixture.service.reads.isEmpty)
        XCTAssertNil(fixture.dialog)
        XCTAssertTrue(fixture.history.isEligible(account: "first@example.com"))
    }

    @MainActor func testPendingConsentCheckDoesNotRetainCoordinator() async throws {
        let fixture = try await Fixture()
        defer { fixture.close() }
        var coordinator: MarketingConsentPromptCoordinator? = MarketingConsentPromptCoordinator(
            history: fixture.history, user: fixture.user, service: fixture.service, flags: fixture.flags)
        weak var releasedCoordinator = coordinator
        coordinator?.presentIfNeeded(from: fixture.presenter)
        await fixture.settle()
        try await waitForConsentState("consent check started") { fixture.service.reads.count == 1 }
        coordinator = nil
        XCTAssertNil(releasedCoordinator, "A pending request must not keep the screen coordinator alive")
        try XCTUnwrap(fixture.service.reads.first).resume(returning: .success(.init(consent: false, status: .notFound)))
        await fixture.settle()
        XCTAssertNil(fixture.dialog)
    }

    @MainActor func testPendingConsentCheckDoesNotRetainPresentingScreen() async throws {
        let fixture = try await Fixture()
        defer { fixture.close() }
        var presenter: UIViewController? = UIViewController()
        weak var releasedPresenter = presenter
        fixture.window.rootViewController = presenter
        fixture.window.layoutIfNeeded()
        presenter?.view.layoutIfNeeded()
        fixture.coordinator.presentIfNeeded(from: presenter!)
        await fixture.settle()
        try await waitForConsentState("consent check started") { fixture.service.reads.count == 1 }
        fixture.window.rootViewController = fixture.presenter
        presenter = nil
        await fixture.settle()
        XCTAssertNil(releasedPresenter, "A pending request must not retain a dismissed screen")
        try XCTUnwrap(fixture.service.reads.first).resume(returning: .success(.init(consent: false, status: .notFound)))
        await fixture.settle()
        XCTAssertNil(fixture.dialog)
    }

    @MainActor func testNewSessionDoesNotWaitForOrUseOldConsentCheck() async throws {
        let fixture = try await Fixture()
        defer { fixture.close() }
        try await fixture.check()
        fixture.user.apiKey = "second-session"
        fixture.user.email = "second@example.com"
        try await fixture.check()
        try await waitForConsentState("new session check started") { fixture.service.reads.count == 2 }
        try XCTUnwrap(fixture.service.reads.first).resume(returning: .success(.init(consent: false, status: .notFound)))
        await fixture.settle()
        XCTAssertNil(fixture.dialog)
        try await fixture.check(expectingNewRequest: false)
        XCTAssertEqual(fixture.service.reads.count, 2, "Old response must not clear the newer request")
        try XCTUnwrap(fixture.service.reads.dropFirst().first).resume(
            returning: .success(.init(consent: false, status: .unsubscribed)))
        await fixture.settle()
        XCTAssertNotNil(fixture.dialog)
        XCTAssertTrue(fixture.history.isEligible(account: "first@example.com"))
        XCTAssertFalse(fixture.history.isEligible(account: "second@example.com"))
        try await fixture.dismiss()
    }

    @MainActor func testDismissedSaveDoesNotBlockNextDialogOrCompleteItsSave() async throws {
        let fixture = try await Fixture()
        defer { fixture.close() }
        try await fixture.showDialog()
        let first = fixture.dialog
        first?.onPrimaryAction?()
        first?.onPrimaryAction?()
        await fixture.settle()
        XCTAssertEqual(fixture.service.writes.count, 1, "Duplicate taps must not issue another save")
        try await fixture.dismiss()
        fixture.history.markPresented(account: "first@example.com", now: Date().addingTimeInterval(-61))
        try await fixture.showDialog()
        let second = fixture.dialog
        XCTAssertNotNil(second)
        XCTAssertFalse(first === second)
        second?.onPrimaryAction?()
        await fixture.settle()
        XCTAssertEqual(fixture.service.writes.count, 2)
        guard fixture.service.writes.count == 2 else { return }
        try XCTUnwrap(fixture.service.writes.first).resume(
            returning: .success(.init(consent: true, status: .subscribed)))
        await fixture.settle()
        XCTAssertTrue(fixture.buttons(in: second).allSatisfy { !$0.isEnabled })
        try XCTUnwrap(fixture.service.writes.dropFirst().first).resume(
            returning: .failure(.failedToParseNetworkResponse))
        await fixture.settle()
        XCTAssertTrue(fixture.buttons(in: second).allSatisfy(\.isEnabled))
        try await fixture.dismiss()
    }

    @MainActor func testSubscribedAndUnavailableStatusesNeverPresent() async throws {
        for status in [RuuviCloudMarketingConsentStatus.subscribed, .unconfirmed, .bounced, .softBounced, .complained] {
            let fixture = try await Fixture()
            defer { fixture.close() }
            try await fixture.check()
            try XCTUnwrap(fixture.service.reads.first).resume(
                returning: .success(.init(consent: false, status: status)))
            await fixture.settle()
            XCTAssertNil(fixture.dialog, status.rawValue)
            XCTAssertTrue(fixture.history.isEligible(account: "first@example.com"))
        }
        let fixture = try await Fixture()
        defer { fixture.close() }
        try await fixture.check()
        try XCTUnwrap(fixture.service.reads.first).resume(
            returning: .success(.init(consent: true, status: .unsubscribed)))
        await fixture.settle()
        XCTAssertNil(fixture.dialog)
    }

    @MainActor func testFailureCanRetryWithoutStartingCooldown() async throws {
        let fixture = try await Fixture()
        defer { fixture.close() }
        try await fixture.check()
        try XCTUnwrap(fixture.service.reads.first).resume(returning: .failure(.failedToParseNetworkResponse))
        await fixture.settle()
        XCTAssertTrue(fixture.history.isEligible(account: "first@example.com"))
        try await fixture.showDialog()
        try await waitForConsentState("new session check started") { fixture.service.reads.count == 2 }
        XCTAssertNotNil(fixture.dialog)
        try await fixture.dismiss()
    }

    @MainActor func testDisabledFlagCannotSubscribe() async throws {
        let fixture = try await Fixture()
        defer { fixture.close() }
        try await fixture.showDialog()
        fixture.flags.showMarketingPreference = false
        fixture.dialog?.onPrimaryAction?()
        await fixture.settle()
        XCTAssertTrue(fixture.service.writes.isEmpty)
        XCTAssertNil(fixture.dialog)
    }

    @MainActor func testSignOutCannotSubscribe() async throws {
        let fixture = try await Fixture()
        defer { fixture.close() }
        try await fixture.showDialog()
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
    private let previousWindow: UIWindow?
    private let animationsEnabled = UIView.areAnimationsEnabled

    init() async throws {
        history = MarketingConsentPromptHistory(defaults: UserDefaults(suiteName: suite)!)
        try await waitForConsentState("active application scene") {
            UIApplication.shared.applicationState == .active
                && UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                    .contains { $0.delegate is SceneDelegate && $0.activationState == .foregroundActive }
        }
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.delegate is SceneDelegate && $0.activationState == .foregroundActive })
        previousWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        coordinator = MarketingConsentPromptCoordinator(history: history, user: user, service: service, flags: flags)
        UIView.setAnimationsEnabled(false)
        window.windowLevel = .alert + 1
        window.rootViewController = presenter
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        presenter.view.layoutIfNeeded()
    }

    deinit {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    func close() {
        presenter.dismiss(animated: false)
        window.isHidden = true
        window.rootViewController = nil
        previousWindow?.makeKeyAndVisible()
        UIView.setAnimationsEnabled(animationsEnabled)
    }

    var dialog: RuuviDialogViewController? { presenter.presentedViewController as? RuuviDialogViewController }
    func check(expectingNewRequest: Bool = true) async throws {
        let count = service.reads.count
        coordinator.presentIfNeeded(from: presenter)
        if expectingNewRequest {
            try await waitForConsentState("consent request") { self.service.reads.count == count + 1 }
        } else {
            await settle()
        }
    }
    func settle() async { try? await Task.sleep(nanoseconds: 150_000_000) }
    func showDialog() async throws {
        try await check()
        try XCTUnwrap(service.reads.last).resume(returning: .success(.init(consent: false, status: .notFound)))
        try await waitForConsentState("consent dialog presented") { self.dialog != nil }
    }
    func dismiss() async throws {
        presenter.dismiss(animated: false)
        try await waitForConsentState("dialog dismissed") { self.dialog == nil }
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
) async throws {
    for _ in 0..<500 {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    _ = try XCTUnwrap(condition() ? true : nil, "Timed out waiting for " + description, file: file, line: line)
}
private extension UIView {
    var consentDescendants: [UIView] { subviews.flatMap { [$0] + $0.consentDescendants } }
}
