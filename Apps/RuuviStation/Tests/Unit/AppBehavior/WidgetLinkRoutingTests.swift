import UIKit
import XCTest
@testable import station

@MainActor final class WidgetLinkRoutingTests: XCTestCase {
    func testWidgetOpensCardsByMacLocalIdentityOrSnapshotIdAndClearsPendingNavigation() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start(names: ["Office"])
        let snapshot = fixture.snapshots[0]
        let router = UniversalLinkRouterImpl()
        let settings = fixture.data.measurements.settings
        for identifier in [snapshot.identifierData.mac!.value, snapshot.identifierData.luid!.value, snapshot.id] {
            settings.setCardToOpenFromWidget(for: identifier)
            router.openSensorCard(with: identifier, settings: settings, from: fixture.view)
            XCTAssertEqual(fixture.output.navigation.last?.0, "widget")
            XCTAssertEqual(fixture.output.navigation.last?.1, snapshot.id)
            XCTAssertNil(settings.cardToOpenFromWidget())
        }
        XCTAssertEqual(fixture.output.navigation.count, 3)
        settings.setCardToOpenFromWidget(for: "missing")
        router.openSensorCard(with: "missing", settings: settings, from: fixture.view)
        XCTAssertEqual(fixture.output.navigation.count, 3)
        XCTAssertEqual(settings.cardToOpenFromWidget(), "missing")
        router.openSensorCard(with: snapshot.id, settings: settings, from: UIViewController())
        XCTAssertEqual(fixture.output.navigation.count, 3)
    }

    func testWidgetDismissesAnOverlayAndPopsBackToDashboardBeforeOpeningTheCard() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start(names: ["Office"])
        let navigation = try XCTUnwrap(fixture.host?.navigation)
        let child = UIViewController()
        navigation.pushViewController(child, animated: false)
        await waitForAppState("navigation appearance") { child.view.window != nil }
        let modal = UIViewController()
        await withCheckedContinuation { continuation in child.present(modal, animated: false) { continuation.resume() }
        }
        let snapshot = fixture.snapshots[0]
        fixture.data.measurements.settings.setCardToOpenFromWidget(for: snapshot.id)
        UniversalLinkRouterImpl().openSensorCard(
            with: snapshot.id, settings: fixture.data.measurements.settings, from: modal)
        await waitForAppState("widget card route") { fixture.output.navigation.contains { $0.0 == "widget" } }
        XCTAssertTrue(navigation.topViewController === fixture.view)
        XCTAssertNil(fixture.data.measurements.settings.cardToOpenFromWidget())
        XCTAssertEqual(fixture.output.navigation.last?.1, snapshot.id)
    }

    func testWidgetFindsTheDashboardInsideATabAndNestedNavigationController() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start(names: ["Office"])
        let host = try XCTUnwrap(fixture.host)
        host.window.rootViewController = nil
        let tabs = UITabBarController()
        tabs.viewControllers = [UIViewController(), host.navigation]
        tabs.selectedIndex = 0
        host.window.rootViewController = tabs
        await flushAppBindings()
        tabs.view.layoutIfNeeded()
        let snapshot = fixture.snapshots[0]
        UniversalLinkRouterImpl().openSensorCard(
            with: snapshot.id, settings: fixture.data.measurements.settings, from: tabs)
        XCTAssertEqual(fixture.output.navigation.last?.0, "widget")
        XCTAssertEqual(fixture.output.navigation.last?.1, snapshot.id)
        XCTAssertEqual(tabs.selectedIndex, 1, "Opening a widget card must reveal its dashboard tab")
    }
}
