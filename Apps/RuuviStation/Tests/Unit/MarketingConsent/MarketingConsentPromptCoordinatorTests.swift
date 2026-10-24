@testable import station
import Future
import RuuviCloud
import RuuviLocal
import RuuviPresenters
import RuuviService
import RuuviUser
import UIKit
import XCTest

final class MarketingConsentPromptCoordinatorTests: XCTestCase {
    @MainActor func testNewSessionDoesNotWaitForOrUseOldConsentCheck() async {
        let fixture = Fixture()
        fixture.check()
        fixture.user.apiKey = "second-session"
        fixture.user.email = "second@example.com"
        fixture.check()
        XCTAssertEqual(fixture.service.reads.count, 2)
        fixture.service.reads[0].succeed(value: .init(consent: false, status: .notFound))
        await fixture.settle()
        XCTAssertNil(fixture.dialog)
        fixture.check()
        XCTAssertEqual(fixture.service.reads.count, 2, "Old response must not clear the newer request")
        fixture.service.reads[1].succeed(value: .init(consent: false, status: .unsubscribed))
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
        XCTAssertEqual(fixture.service.writes.count, 1, "Duplicate taps must not issue another save")
        await fixture.dismiss()
        fixture.history.markPresented(account: "first@example.com", now: Date().addingTimeInterval(-61))
        await fixture.showDialog()
        let second = fixture.dialog
        XCTAssertNotNil(second)
        XCTAssertFalse(first === second)
        second?.onPrimaryAction?()
        XCTAssertEqual(fixture.service.writes.count, 2)
        guard fixture.service.writes.count == 2 else { return }
        fixture.service.writes[0].succeed(value: .init(consent: true, status: .subscribed))
        await fixture.settle()
        XCTAssertTrue(fixture.buttons(in: second).allSatisfy { !$0.isEnabled })
        fixture.service.writes[1].fail(error: .failedToParseNetworkResponse)
        await fixture.settle()
        XCTAssertTrue(fixture.buttons(in: second).allSatisfy(\.isEnabled))
        await fixture.dismiss()
    }

    @MainActor func testSubscribedAndUnavailableStatusesNeverPresent() async {
        for status in [RuuviCloudMarketingConsentStatus.subscribed, .unconfirmed, .bounced, .softBounced, .complained] {
            let fixture = Fixture()
            fixture.check()
            fixture.service.reads[0].succeed(value: .init(consent: false, status: status))
            await fixture.settle()
            XCTAssertNil(fixture.dialog, status.rawValue)
            XCTAssertTrue(fixture.history.isEligible(account: "first@example.com"))
        }
        let fixture = Fixture()
        fixture.check()
        fixture.service.reads[0].succeed(value: .init(consent: true, status: .unsubscribed))
        await fixture.settle()
        XCTAssertNil(fixture.dialog)
    }

    @MainActor func testFailureCanRetryWithoutStartingCooldown() async {
        let fixture = Fixture()
        fixture.check()
        fixture.service.reads[0].fail(error: .failedToParseNetworkResponse)
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

private final class ConsentService: RuuviServiceMarketingConsent {
    var reads = [Promise<RuuviCloudMarketingConsent, RuuviServiceError>]()
    var writes = [Promise<RuuviCloudMarketingConsent, RuuviServiceError>]()
    func getMarketingConsent() -> Future<RuuviCloudMarketingConsent, RuuviServiceError> {
        let promise = Promise<RuuviCloudMarketingConsent, RuuviServiceError>()
        reads.append(promise)
        return promise.future
    }
    func set(marketingPreference: Bool) -> Future<RuuviCloudMarketingConsent, RuuviServiceError> {
        XCTAssertTrue(marketingPreference)
        let promise = Promise<RuuviCloudMarketingConsent, RuuviServiceError>()
        writes.append(promise)
        return promise.future
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
    func check() { coordinator.presentIfNeeded(from: presenter) }
    func settle() async { try? await Task.sleep(nanoseconds: 150_000_000) }
    func showDialog() async {
        check()
        service.reads.last?.succeed(value: .init(consent: false, status: .notFound))
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
