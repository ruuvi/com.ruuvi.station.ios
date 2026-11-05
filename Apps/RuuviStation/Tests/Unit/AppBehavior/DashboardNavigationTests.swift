import RuuviOntology
import XCTest
@testable import station

@MainActor final class DashboardNavigationTests: XCTestCase {
    func testCardDestinationsCarryTheCompleteSensorContext() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let card = try await fixture.start(version: 225)
        fixture.presenter.viewDidTriggerSettings(for: card)
        fixture.presenter.viewDidTriggerAlerts(for: card)
        fixture.presenter.viewDidTriggerChart(for: card)
        fixture.presenter.viewDidTriggerOpenCardImageView(for: card)
        XCTAssertEqual(fixture.router.cards.map(\.menu), [.settings, .alerts, .graph, .measurement])
        XCTAssertTrue(
            fixture.router.cards.allSatisfy {
                $0.id == card.id && $0.sensors == [card.id] && $0.snapshots == [card.id]
            })
        fixture.presenter.viewDidTriggerRemove(for: card)
        XCTAssertEqual(fixture.router.removed, [card.id])
        fixture.presenter.viewDidTriggerOpenCardImageView(for: nil)
        fixture.presenter.viewDidTriggerOpenSensorCardFromWidget(for: nil)
        XCTAssertEqual(fixture.router.cards.count, 4)
    }

    func testChartsPromptOnceAndAcceptingConnectionPersistsTheChoice() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let card = try await fixture.start()
        card.connectionData.isConnectable = true
        fixture.presenter.viewDidTriggerChart(for: card)
        XCTAssertEqual(fixture.view.chartPrompts, [card.id])
        XCTAssertTrue(fixture.router.cards.isEmpty)
        fixture.presenter.viewDidConfirmToKeepConnectionChart(to: card)
        XCTAssertTrue(fixture.services.manager.getConnectionStatus(for: card).keepConnection)
        XCTAssertTrue(fixture.settingsService.keepConnectionDialogWasShown(for: card))
        fixture.presenter.viewDidTriggerChart(for: card)
        XCTAssertEqual(fixture.view.chartPrompts.count, 1)
        XCTAssertEqual(fixture.router.cards.map(\.menu), [.graph, .graph])
    }

    func testDecliningConnectionStillOpensChartsAndSettingsWithoutPairing() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let card = try await fixture.start()
        fixture.presenter.coordinatorDidReceiveEvent(
            fixture.services.coordinator,
            event: .newSensorAdded(try XCTUnwrap(fixture.services.manager.getSensor(for: card.id)), newOrder: []))
        XCTAssertEqual(fixture.view.settingsPrompts.first?.0, card.id)
        XCTAssertTrue(fixture.view.settingsPrompts.first?.1 == true)
        fixture.presenter.viewDidDismissKeepConnectionDialogSettings(for: card, newlyAddedSensor: true)
        fixture.presenter.viewDidDismissKeepConnectionDialogChart(for: card)
        XCTAssertEqual(fixture.router.cards.map(\.menu), [.settings, .graph])
        XCTAssertFalse(fixture.services.manager.getConnectionStatus(for: card).keepConnection)
        fixture.presenter.viewDidConfirmToKeepConnectionSettings(to: card, newlyAddedSensor: false)
        XCTAssertTrue(fixture.services.manager.getConnectionStatus(for: card).keepConnection)
        XCTAssertEqual(fixture.router.cards.last?.menu, .settings)
    }

    func testDashboardTapPreferenceAndOneTimeCardOverrideSelectTheExpectedTab() async throws {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        let card = try await fixture.start(version: 225)
        let settings = fixture.services.data.measurements.settings
        settings.dashboardTapActionType = .chart
        settings.showFullSensorCardOnDashboardTap = true
        fixture.presenter.viewDidTriggerDashboardCard(for: card)
        XCTAssertFalse(settings.showFullSensorCardOnDashboardTap)
        fixture.presenter.viewDidTriggerDashboardCard(for: card)
        settings.dashboardTapActionType = .card
        fixture.presenter.viewDidTriggerDashboardCard(for: card)
        fixture.presenter.viewDidTriggerOpenSensorCardFromWidget(for: card)
        XCTAssertEqual(fixture.router.cards.map(\.menu), [.measurement, .graph, .measurement, .measurement])
    }

    func testMainActionsRouteToTheSelectedScreen() {
        let fixture = DashboardFixture()
        defer { fixture.cleanup() }
        fixture.presenter.viewDidTriggerMenu()
        fixture.presenter.viewDidTriggerSignIn()
        fixture.presenter.viewDidTriggerAddSensors()
        fixture.presenter.viewDidTriggerBuySensors()
        XCTAssertEqual(fixture.router.paths, ["menu", "signin", "discover", "products"])
    }
}
