import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class DashboardModuleOutputTests: XCTestCase {
    func testMenuActionsDismissTheMenuBeforeRoutingToTheRequestedDestination() {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let menu = DashboardMenuSpy()
        fixture.presenter.menu(module: menu, didSelectAddRuuviTag: nil)
        fixture.presenter.menu(module: menu, didSelectSettings: nil)
        fixture.presenter.menu(module: menu, didSelectAbout: nil)
        fixture.presenter.menu(module: menu, didSelectWhatToMeasure: nil)
        fixture.presenter.menu(module: menu, didSelectGetMoreSensors: nil)
        fixture.presenter.menu(module: menu, didSelectSignIn: nil)
        fixture.presenter.menu(module: menu, didSelectOpenConfig: nil)
        fixture.presenter.menu(module: menu, didSelectOpenMyRuuviAccount: nil)
        XCTAssertEqual(menu.dismissals, 8)
        XCTAssertEqual(
            fixture.router.paths, ["discover", "settings", "about", "measure", "menu-products", "signin", "account"])
        fixture.presenter.menu(module: menu, didSelectNewsletter: nil)
        XCTAssertTrue(fixture.router.urls.isEmpty)
        let url = URL(string: "https://ruuvi.com/newsletter/")!
        fixture.presenter.menu(module: menu, didSelectNewsletter: url)
        XCTAssertEqual(fixture.router.urls, [url])
        XCTAssertEqual(menu.dismissals, 10)
    }

    func testFeedbackIncludesDiagnosticsAndDoesNotPresentAfterTheDashboardIsReleased() throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let info = DashboardInfoSpy()
        let mail = DashboardMailSpy()
        let menu = DashboardMenuSpy()
        fixture.presenter.infoProvider = info
        fixture.presenter.mailComposerPresenter = mail
        fixture.presenter.feedbackEmail = "support@example.invalid"
        fixture.presenter.feedbackSubject = "Sensor feedback"
        fixture.presenter.menu(module: menu, didSelectFeedback: nil)
        XCTAssertEqual(menu.dismissals, 1)
        XCTAssertTrue(mail.messages.isEmpty)
        let complete = try XCTUnwrap(info.completion)
        complete("Ruuvi Station, iPhone 18 Pro, iOS 27.2")
        XCTAssertEqual(mail.messages.first?.email, "support@example.invalid")
        XCTAssertEqual(mail.messages.first?.subject, "Sensor feedback")
        XCTAssertEqual(mail.messages.first?.body, "\n\nRuuvi Station, iPhone 18 Pro, iOS 27.2")
        fixture.presenter.menu(module: menu, didSelectFeedback: nil)
        weak var presenter = fixture.presenter
        fixture.presenter = nil
        XCTAssertNil(presenter)
        info.completion?("Late diagnostics")
        XCTAssertEqual(mail.messages.count, 1)
    }

    func testLoginRefreshesAuthorizationAndPromptsForConsentOnlyAfterDismissal() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        _ = try await fixture.start()
        let module = DashboardSignInModuleSpy()
        fixture.services.user.isAuthorized = true
        fixture.presenter.signIn(module: module, didSuccessfulyLogin: nil)
        XCTAssertTrue(fixture.view.isAuthorized)
        XCTAssertEqual(fixture.view.marketingPrompts, 0)
        try XCTUnwrap(module.completion)()
        XCTAssertEqual(fixture.view.marketingPrompts, 1)
        fixture.presenter.signIn(module: module, didCloseSignInWithoutAttempt: nil)
        try XCTUnwrap(module.completion)()
        fixture.presenter.signIn(module: module, didSelectUseWithoutAccount: nil)
        try XCTUnwrap(module.completion)()
        XCTAssertEqual(module.dismissals, 3)
        XCTAssertEqual(fixture.view.marketingPrompts, 1)
        await flushAppBindings()
    }

    func testSettingsDelegatesRefreshUnitsLanguageAndRestartObservationAfterCalibrationOrRemoval() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let snapshot = try await fixture.start()
        let service = fixture.settingsService
        fixture.presenter.settingsService(service, measurementUnitsDidChange: true)
        fixture.presenter.settingsService(service, languageDidChange: true)
        XCTAssertEqual(fixture.view.lists.suffix(2), [[snapshot.id], [snapshot.id]])
        let reactor = fixture.services.data.reactor
        let oldTokens = Set(reactor.sensors.keys)
        fixture.presenter.settingsService(service, calibrationSettingsDidChange: true)
        XCTAssertTrue(oldTokens.isDisjoint(with: reactor.sensors.keys))
        XCTAssertFalse(reactor.sensors.isEmpty)
        let removal = SensorRemovalModuleSpy()
        fixture.presenter.sensorRemovalDidDismiss(module: removal)
        let beforeRemoval = Set(reactor.sensors.keys)
        fixture.presenter.sensorRemovalDidRemoveTag(
            module: removal, ruuviTag: try XCTUnwrap(fixture.services.manager.getSensor(for: snapshot.id)))
        XCTAssertEqual(removal.dismissals, 2)
        XCTAssertTrue(beforeRemoval.isDisjoint(with: reactor.sensors.keys))
        await flushAppBindings()
    }
}

private final class DashboardMenuSpy: MenuModuleInput {
    var dismissals = 0
    func configure(output: MenuModuleOutput) {}
    func dismiss() { dismissals += 1 }
}
private final class DashboardSignInModuleSpy: SignInBenefitsModuleInput {
    var dismissals = 0
    var completion: (() -> Void)?
    func configure(output: SignInBenefitsModuleOutput?) {}
    func dismiss(completion: (() -> Void)?) { dismissals += 1; self.completion = completion }
}
private final class DashboardInfoSpy: InfoProvider {
    let deviceModel = "iPhone 18 Pro"
    let appVersion = "1.0"
    let appName = "Ruuvi Station"
    let systemName = "iOS"
    let systemVersion = "27.2"
    var completion: ((String) -> Void)?
    func summary(completion: @escaping (String) -> Void) { self.completion = completion }
}
private final class DashboardMailSpy: MailComposerPresenter {
    struct Message { let email: String; let subject: String; let body: String? }
    var messages = [Message]()
    func present(email: String, subject: String, body: String?) {
        messages.append(.init(email: email, subject: subject, body: body))
    }
    func present(email: String) { present(email: email, subject: "", body: nil) }
}
