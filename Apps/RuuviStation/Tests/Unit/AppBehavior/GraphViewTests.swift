import BTKit
import DGCharts
import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class GraphViewTests: XCTestCase {
    func testChartsRenderReuseViewsAndSwitchBetweenLoadingDataAndEmptyStates() async throws {
        let fixture = try GraphViewFixture()
        defer { fixture.close() }
        let view = fixture.controller
        XCTAssertTrue(view.viewIsVisible)
        XCTAssertTrue(view.graphIsVisibleForUser)
        view.view.isHidden = true
        XCTAssertFalse(view.graphIsVisibleForUser)
        view.view.isHidden = false
        view.view.alpha = 0
        XCTAssertFalse(view.graphIsVisibleForUser)
        view.view.alpha = 1
        view.setChartLoading(hideCharts: true)
        XCTAssertEqual(view.noDataLabel.alpha, 0)
        fixture.loadCharts()
        XCTAssertEqual(fixture.charts.count, 4)
        XCTAssertTrue(fixture.charts.allSatisfy { $0.underlyingView.data?.entryCount == 2 })
        XCTAssertEqual(view.noDataLabel.alpha, 0)
        let identities = Set(fixture.charts.map(ObjectIdentifier.init))
        view.createChartViews(from: fixture.variants)
        XCTAssertEqual(Set(fixture.charts.map(ObjectIdentifier.init)), identities)
        view.setHasChartData(false)
        XCTAssertEqual(view.noDataLabel.alpha, 1)
        view.setChartLoading(hideCharts: false)
        XCTAssertEqual(view.noDataLabel.alpha, 0)
        view.setHasChartData(true)
        XCTAssertEqual(view.noDataLabel.alpha, 0)
        view.clearChartHistory()
        XCTAssertTrue(fixture.charts.allSatisfy { ($0.underlyingView.data?.entryCount ?? 0) == 0 })
        view.setChartViewData(from: [], settings: fixture.graph.measurements.settings)
        await flushAppBindings()
    }

    func testHistoryAndMoreMenusApplySelectionsAndKeepTheCorrectCheckmark() async throws {
        let fixture = try GraphViewFixture()
        defer { fixture.close() }
        fixture.loadCharts()
        let controller = fixture.controller
        controller.showChartStat = true
        controller.showChartAll = false
        controller.historyLengthInHours = 2
        let twoHours = "2 \(RuuviLocalization.hours)".lowercased()
        XCTAssertEqual(try fixture.action(twoHours).state, .on)
        fixture.perform(try fixture.action("1 \(RuuviLocalization.hour)".lowercased()))
        XCTAssertEqual(fixture.graph.measurements.settings.chartDurationHours, 1)
        XCTAssertEqual(controller.historyLengthInHours, 1)
        fixture.perform(try fixture.action(RuuviLocalization.all))
        XCTAssertTrue(controller.showChartAll)
        XCTAssertTrue(fixture.graph.measurements.settings.chartShowAll)
        XCTAssertEqual(try fixture.action(RuuviLocalization.all).state, .on)
        fixture.perform(try fixture.action(RuuviLocalization.chartStatHide))
        XCTAssertFalse(controller.showChartStat)
        XCTAssertEqual(fixture.graph.interactor.statistics, [false])
        fixture.perform(try fixture.action(RuuviLocalization.chartStatShow))
        XCTAssertTrue(controller.showChartStat)
        controller.chartsPerScreen = 2
        fixture.perform(try fixture.action(RuuviLocalization.increaseGraphSize))
        XCTAssertEqual(controller.chartsPerScreen, 1)
        fixture.perform(try fixture.action(RuuviLocalization.decreaseGraphSize))
        XCTAssertEqual(controller.chartsPerScreen, 2)
        await flushAppBindings()
    }

    func testSyncStatusTextAndCancelButtonFollowTheActiveSensor() throws {
        let fixture = try GraphViewFixture()
        defer { fixture.close() }
        let view = fixture.controller
        let snapshot = fixture.graph.measurements.snapshot
        let cases: [(GraphGattSyncStatus, String)] = [
            (.queued, RuuviLocalization.TagCharts.Status.queued),
            (.progress(.connecting), RuuviLocalization.TagCharts.Status.connecting),
            (.progress(.serving), RuuviLocalization.TagCharts.Status.serving),
            (.progress(.reading(12)), RuuviLocalization.readingHistoryX(12)),
            (.progress(.disconnecting), RuuviLocalization.TagCharts.Status.disconnecting),
            (.progress(.success), RuuviLocalization.TagCharts.Status.success),
        ]
        for (status, title) in cases {
            view.setSync(status: status, for: snapshot)
            XCTAssertEqual(view.syncStatusLabel.text, title)
            XCTAssertEqual(view.syncProgressView.alpha, 1)
        }
        view.setSync(status: nil, for: snapshot)
        XCTAssertEqual(view.syncProgressView.alpha, 0)
        view.setSync(status: .queued, for: snapshot)
        view.setSyncProgressViewHidden()
        XCTAssertEqual(view.syncProgressView.alpha, 0)
        view.setActiveSnapshot(nil)
        view.setSync(status: .queued, for: snapshot)
        XCTAssertEqual(view.syncProgressView.alpha, 0)
    }

    func testLiveDataAndScrollingPreserveTheRenderedChartValues() async throws {
        let fixture = try GraphViewFixture()
        defer { fixture.close() }
        fixture.loadCharts()
        let controller = fixture.controller
        let variant = fixture.variants[0]
        let now = Date().timeIntervalSince1970
        controller.updateChartViewData(
            [variant: [ChartDataEntry(x: now + 60, y: 25)]], isFirstEntry: false,
            firstEntry: nil, settings: fixture.graph.measurements.settings)
        let chart = try XCTUnwrap(fixture.charts.first)
        XCTAssertEqual(chart.underlyingView.data?.entryCount, 3)
        controller.updateLatestMeasurement(
            [variant: ChartDataEntry(x: now + 60, y: 25)], alertStates: [variant: true],
            settings: fixture.graph.measurements.settings)
        controller.updateLatestAlertStates([variant: false])
        controller.scroll(to: fixture.variants.last!)
        controller.scrollViewWillBeginDragging(controller.scrollView)
        controller.scrollViewDidEndDragging(controller.scrollView, willDecelerate: true)
        controller.scrollViewDidEndDecelerating(controller.scrollView)
        controller.scrollViewDidEndDragging(controller.scrollView, willDecelerate: false)
        controller.resetScrollPosition()
        XCTAssertEqual(controller.scrollView.contentOffset, .zero)
        controller.chartMarkerInteractionDidBegin(chart)
        controller.chartMarkerInteractionDidEnd(chart)
        controller.chartDidTranslate(chart)
        controller.chartValueDidDeselect(chart)
        XCTAssertEqual(chart.underlyingView.data?.entryCount, 3)
        await flushAppBindings()
    }
}
