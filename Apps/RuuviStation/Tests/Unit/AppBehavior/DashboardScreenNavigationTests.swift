import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class DashboardScreenNavigationTests: XCTestCase {
    func testCardMenusRouteEveryActionToTheSelectedSensorAndOfferOnlyValidMoves() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let rows = [
            (RuuviLocalization.mainView, "image"), (RuuviLocalization.historyView, "chart"),
            (RuuviLocalization.TagSettings.Label.Alerts.text, "alerts"),
            (RuuviLocalization.Settings.NavigationItem.title, "settings"), (RuuviLocalization.remove, "remove"),
        ]
        for index in fixture.snapshots.indices {
            let menu = try fixture.menu(at: index)
            let titles = fixture.actions(menu).map(\.title)
            XCTAssertEqual(titles.contains(RuuviLocalization.moveUp), index > 0)
            XCTAssertEqual(titles.contains(RuuviLocalization.moveDown), index < fixture.snapshots.count - 1)
            for (title, destination) in rows {
                try fixture.choose(title, in: menu)
                XCTAssertEqual(fixture.output.navigation.last?.0, destination)
                XCTAssertEqual(fixture.output.navigation.last?.1, fixture.snapshots[index].id)
            }
        }
        fixture.view.collectionView(fixture.collection, didSelectItemAt: IndexPath(item: 1, section: 0))
        XCTAssertEqual(fixture.output.navigation.last?.0, "card")
        XCTAssertEqual(fixture.output.navigation.last?.1, fixture.snapshots[1].id)
        fixture.view.didTapAlertButton(for: fixture.snapshots[2])
        XCTAssertEqual(fixture.output.navigation.last?.0, "alerts")
        XCTAssertEqual(fixture.output.navigation.last?.1, fixture.snapshots[2].id)
    }

    func testMoveCommandsPreserveEverySensorAndSelectManualOrdering() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let ids = fixture.snapshots.compactMap(\.identifierData.mac?.value)
        try fixture.choose(RuuviLocalization.moveDown, in: fixture.menu(at: 0))
        XCTAssertEqual(fixture.output.orders.last?.0, .manual)
        XCTAssertEqual(fixture.output.orders.last?.1, [ids[1], ids[0], ids[2]])
        try fixture.choose(RuuviLocalization.moveUp, in: fixture.menu(at: 2))
        XCTAssertEqual(fixture.output.orders.last?.1, [ids[0], ids[2], ids[1]])
    }

    func testViewMenuReflectsPreferencesAndForwardsCardTypeTapActionAndReset() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start()
        let button = try XCTUnwrap(
            fixture.descendants(fixture.view.view).compactMap { $0 as? RuuviContextMenuButton }
                .first { $0.buttonTitleLabel.text == RuuviLocalization.view })
        var menu = try XCTUnwrap(button.button.menu)
        XCTAssertEqual(fixture.actions(menu).first { $0.title == RuuviLocalization.simpleCards }?.state, .on)
        XCTAssertEqual(fixture.actions(menu).first { $0.title == RuuviLocalization.openSensorView }?.state, .on)
        XCTAssertFalse(fixture.actions(menu).contains { $0.title == RuuviLocalization.resetOrder })
        try fixture.choose(RuuviLocalization.imageCards, in: menu)
        try fixture.choose(RuuviLocalization.simpleCards, in: menu)
        try fixture.choose(RuuviLocalization.openHistoryView, in: menu)
        try fixture.choose(RuuviLocalization.openSensorView, in: menu)
        XCTAssertEqual(fixture.output.types, [.image, .simple])
        XCTAssertEqual(fixture.output.taps, [.chart, .card])
        fixture.view.dashboardType = .image
        fixture.view.dashboardTapActionType = .chart
        fixture.view.dashboardSortingType = .manual
        menu = try XCTUnwrap(button.button.menu)
        XCTAssertEqual(fixture.actions(menu).first { $0.title == RuuviLocalization.imageCards }?.state, .on)
        XCTAssertEqual(fixture.actions(menu).first { $0.title == RuuviLocalization.openHistoryView }?.state, .on)
        try fixture.choose(RuuviLocalization.resetOrder, in: menu)
        XCTAssertEqual(fixture.output.resets, 1)
    }

    func testEmptyStateAndSignInBannerForwardOnboardingAndCanBeHidden() async throws {
        let fixture = DashboardScreenFixture()
        defer { fixture.cleanup() }
        try await fixture.start(names: [])
        let empty = try XCTUnwrap(fixture.descendants(fixture.view.view).compactMap { $0 as? NoSensorView }.first)
        XCTAssertFalse(empty.isHidden)
        XCTAssertTrue(fixture.collection.isHidden)
        fixture.view.didTapSignInButton(sender: empty)
        fixture.view.didTapAddSensorButton(sender: empty)
        fixture.view.didTapBuySensorButton(sender: empty)
        XCTAssertEqual(fixture.output.navigation.map(\.0), ["signin", "add", "buy"])
        fixture.view.isAuthorized = true
        fixture.view.showNoSensorsAddedMessage(show: false)
        XCTAssertTrue(empty.isHidden)
        XCTAssertFalse(fixture.collection.isHidden)
        let banner = try XCTUnwrap(
            fixture.descendants(fixture.view.view).compactMap { $0 as? DashboardSignInBannerView }.first)
        fixture.view.shouldShowSignInBanner = true
        await flushAppBindings()
        XCTAssertEqual(banner.alpha, 1)
        fixture.view.didTapSignInButton(sender: banner)
        fixture.view.didTapCloseButton(sender: banner)
        XCTAssertEqual(fixture.output.hides, 1)
        XCTAssertEqual(fixture.output.navigation.last?.0, "signin")
        fixture.view.shouldShowSignInBanner = false
        await flushAppBindings()
        XCTAssertEqual(banner.alpha, 0)
        XCTAssertEqual(fixture.output.lifecycle.prefix(2), ["load", "appear"])
    }
}
