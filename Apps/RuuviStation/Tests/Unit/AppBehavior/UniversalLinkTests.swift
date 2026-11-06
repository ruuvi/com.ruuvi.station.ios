import Foundation
import LightRoute
import RuuviLocal
import UIKit
import XCTest
@testable import station

@MainActor final class UniversalLinkTests: XCTestCase {
    func testConsecutiveVerificationLinksKeepTheirOwnTokensUntilTheMainQueueHandlesThem() async throws {
        let view = UIViewController()
        let fixture = UniversalLinkFixture(view: { view })
        fixture.coordinator.processUniversalLink(
            url: try XCTUnwrap(URL(string: "https://ruuvi.com/verify?token=first")))
        fixture.coordinator.processUniversalLink(
            url: try XCTUnwrap(URL(string: "https://ruuvi.com/verify?token=second")))
        await flushAppBindings()
        XCTAssertEqual(fixture.router.tokens, ["first", "second"])
        XCTAssertTrue(fixture.router.sources.allSatisfy { $0 === view })
    }

    func testAuthorizedMissingTokenUnknownPathAndMissingViewCannotOpenVerification() async throws {
        let fixture = UniversalLinkFixture(view: { UIViewController() })
        var fallback = 0
        let observation = NotificationCenter.default.addObserver(
            forName: .DidOpenWithUniversalLink, object: nil, queue: .main
        ) { _ in fallback += 1 }
        defer { NotificationCenter.default.removeObserver(observation) }
        fixture.user.isAuthorized = true
        fixture.coordinator.processUniversalLink(
            url: try XCTUnwrap(URL(string: "https://ruuvi.com/verify?token=secret")))
        await flushAppBindings()
        fixture.user.isAuthorized = false
        fixture.coordinator.processUniversalLink(url: try XCTUnwrap(URL(string: "https://ruuvi.com/verify")))
        await flushAppBindings()
        fixture.coordinator.processUniversalLink(
            url: try XCTUnwrap(URL(string: "https://ruuvi.com/unknown?token=secret")))
        fixture.coordinator.processUniversalLink(url: try XCTUnwrap(URL(string: "https://ruuvi.com/dashboard")))
        await flushAppBindings()
        XCTAssertTrue(fixture.router.tokens.isEmpty)
        XCTAssertEqual(fallback, 2)
        let absent = UniversalLinkFixture(view: { nil })
        absent.coordinator.processUniversalLink(
            url: try XCTUnwrap(URL(string: "https://ruuvi.com/verify?token=secret")))
        absent.coordinator.processWidgetLink(macId: "missing")
        await flushAppBindings()
        XCTAssertTrue(absent.router.tokens.isEmpty)
        XCTAssertTrue(absent.router.sensorIDs.isEmpty)
    }

    func testVerificationNotificationCannotHaveItsRouteReplacedByAQueryParameter() async throws {
        let view = SignInViewController()
        let fixture = UniversalLinkFixture(view: { view })
        var notifications = [Notification]()
        let observation = NotificationCenter.default.addObserver(
            forName: .DidOpenWithUniversalLink, object: nil, queue: .main
        ) { notifications.append($0) }
        defer { NotificationCenter.default.removeObserver(observation) }
        fixture.coordinator.processUniversalLink(
            url: try XCTUnwrap(URL(string: "https://ruuvi.com/verify?token=abc&path=unrelated")))
        await flushAppBindings()
        XCTAssertEqual(notifications.count, 1)
        XCTAssertEqual(notifications.first?.userInfo?["path"] as? UniversalLinkType, .verify)
        XCTAssertEqual(notifications.first?.userInfo?["token"] as? String, "abc")
        XCTAssertTrue(fixture.router.tokens.isEmpty)
    }

    func testWidgetLinkPublishesTheSensorIdentityAndRoutesFromTheCurrentScreen() async {
        let view = UIViewController()
        let fixture = UniversalLinkFixture(view: { view })
        var observed = [String]()
        let observation = NotificationCenter.default.addObserver(
            forName: .DidOpenWithWidgetDeepLink, object: nil, queue: .main
        ) {
            if let value = $0.userInfo?[WidgetDeepLinkMacIdKey.macId] as? String { observed.append(value) }
        }
        defer { NotificationCenter.default.removeObserver(observation) }
        fixture.coordinator.processWidgetLink(macId: "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(observed, ["AA:BB:CC:DD:EE:FF"])
        await flushAppBindings()
        XCTAssertEqual(fixture.router.sensorIDs, observed)
        XCTAssertTrue(fixture.router.sources.last === view)
    }
}

@MainActor private final class UniversalLinkFixture {
    let user = DefaultsUserSpy()
    let settings = AppTestSettings()
    let router = UniversalLinkRouterSpy()
    let coordinator: UniversalLinkCoordinatorImpl
    init(view: @escaping () -> UIViewController?) {
        coordinator = UniversalLinkCoordinatorImpl(topViewController: view)
        coordinator.ruuviUser = user
        coordinator.settings = settings
        coordinator.router = router
    }
}

private final class UniversalLinkRouterSpy: UniversalLinkRouter {
    var tokens = [String]()
    var sensorIDs = [String]()
    var sources = [UIViewController]()
    func openSignInVerify(with code: String, from transitionHandler: TransitionHandler) {
        tokens.append(code)
        if let source = transitionHandler as? UIViewController { sources.append(source) }
    }
    func openSensorCard(with macId: String, settings: RuuviLocalSettings, from transitionHandler: TransitionHandler) {
        sensorIDs.append(macId)
        if let source = transitionHandler as? UIViewController { sources.append(source) }
    }
}
