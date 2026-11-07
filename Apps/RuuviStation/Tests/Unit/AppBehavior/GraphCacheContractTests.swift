import DGCharts
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class GraphCacheContractTests: XCTestCase {
    private let celsius = MeasurementDisplayVariant(type: .temperature, temperatureUnit: .celsius)

    func testReturningToASensorRestoresItsOwnHistoryAndLatestReadingImmediately() async throws {
        let fixture = GraphFixture()
        let other = MeasurementFixture()
        defer { fixture.cleanup(); other.cleanup() }
        await render(fixture.measurements, temperature: 21, in: fixture)
        await render(other, temperature: 35, in: fixture)
        let cleared = fixture.view.cleared
        let count = fixture.view.charts.count
        select(fixture.measurements, in: fixture)
        XCTAssertEqual(fixture.view.cleared, cleared)
        XCTAssertEqual(fixture.view.charts.count, count + 1)
        XCTAssertEqual(values(fixture), [21])
        XCTAssertEqual(fixture.view.modules.last, [celsius])
        XCTAssertEqual(fixture.view.hasData.last, true)
        XCTAssertEqual(try XCTUnwrap(fixture.view.latest.last?[celsius]??.y), 21)
        select(other, in: fixture)
        XCTAssertEqual(values(fixture), [35])
    }

    func testShorteningTheHistoryWindowDiscardsExpiredCachedReadings() async {
        let fixture = GraphFixture()
        let other = MeasurementFixture()
        defer { fixture.cleanup(); other.cleanup() }
        fixture.measurements.settings.chartShowAll = false
        fixture.measurements.settings.chartDurationHours = 24
        await render(fixture.measurements, temperature: 21, age: 7200, in: fixture)
        await render(other, temperature: 35, in: fixture)
        fixture.measurements.settings.chartDurationHours = 1
        let cleared = fixture.view.cleared
        select(fixture.measurements, in: fixture)
        XCTAssertEqual(fixture.view.cleared, cleared + 1)
        XCTAssertEqual(fixture.view.loading.last, true)
        fixture.presenter.createChartModules(from: [celsius])
        fixture.interactor.ruuviTagData = []
        fixture.presenter.interactorDidFinishLoadingHistory()
        fixture.presenter.interactorDidUpdate(sensor: fixture.measurements.sensor.any)
        await waitForAppState("expired history cleared") { fixture.view.hasData.last == false }
        XCTAssertTrue(values(fixture).isEmpty)
    }

    func testCacheEvictionRequiresFreshHistoryWithoutLeakingAnotherSensorsValues() async {
        let fixture = GraphFixture()
        let others = (0..<5).map { _ in MeasurementFixture() }
        defer { fixture.cleanup(); others.forEach { $0.cleanup() } }
        await render(fixture.measurements, temperature: 20, in: fixture)
        for (index, other) in others.enumerated() {
            await render(other, temperature: Double(30 + index), in: fixture)
        }
        let cleared = fixture.view.cleared
        select(fixture.measurements, in: fixture)
        XCTAssertEqual(fixture.view.cleared, cleared + 1)
        XCTAssertEqual(fixture.view.loading.last, true)
        select(others[0], in: fixture)
        XCTAssertEqual(values(fixture), [30])
        XCTAssertEqual(fixture.view.cleared, cleared + 1)
    }

    func testAlertChangesAreScopedToTheSensorAndStatisticsFollowSettings() async {
        let fixture = GraphFixture()
        let other = MeasurementFixture()
        defer { fixture.cleanup(); other.cleanup() }
        fixture.measurements.settings.showAlertsRangeInGraph = true
        fixture.presenter.start(shouldSyncFromCloud: false)
        await render(fixture.measurements, temperature: 21, in: fixture)
        let before = fixture.view.alertStates.count
        fixture.notifications.post(name: .RuuviServiceAlertDidChange, object: nil)
        fixture.notifications.post(
            name: .RuuviServiceAlertDidChange, object: nil,
            userInfo: [RuuviServiceAlertDidChangeKey.physicalSensor: other.sensor])
        XCTAssertEqual(fixture.view.alertStates.count, before)
        fixture.notifications.post(
            name: .RuuviServiceAlertDidChange, object: nil,
            userInfo: [RuuviServiceAlertDidChangeKey.physicalSensor: fixture.measurements.sensor])
        XCTAssertEqual(fixture.view.alertStates.count, before + 1)
        fixture.measurements.settings.showAlertsRangeInGraph = false
        fixture.notifications.post(
            name: .RuuviServiceAlertDidChange, object: nil,
            userInfo: [RuuviServiceAlertDidChangeKey.physicalSensor: fixture.measurements.sensor])
        XCTAssertEqual(fixture.view.alertStates.count, before + 1)
        fixture.measurements.settings.chartStatsOn = true
        fixture.notifications.post(name: .ChartStatsOnDidChange, object: nil)
        await waitForAppState("chart statistics enabled") { fixture.view.showChartStat }
        fixture.presenter.stop()
        fixture.measurements.settings.chartStatsOn = false
        fixture.notifications.post(name: .ChartStatsOnDidChange, object: nil)
        await flushAppBindings()
        XCTAssertTrue(fixture.view.showChartStat, "Stopped screens no longer consume settings notifications")
    }

    private func select(_ sensor: MeasurementFixture, in fixture: GraphFixture) {
        sensor.snapshot.displayData.measurementVisibility = .init(
            availableVariants: [celsius], visibleVariants: [celsius])
        fixture.presenter.configure(with: sensor.snapshot, sensor: sensor.sensor.any, settings: nil)
    }
    private func render(
        _ sensor: MeasurementFixture, temperature: Double, age: TimeInterval = 60,
        in fixture: GraphFixture
    ) async {
        select(sensor, in: fixture)
        fixture.presenter.createChartModules(from: [celsius])
        fixture.interactor.ruuviTagData = [
            sensor.record(date: Date().addingTimeInterval(-age), temperature: temperature).measurement
        ]
        fixture.presenter.interactorDidFinishLoadingHistory()
        fixture.presenter.interactorDidUpdate(sensor: sensor.sensor.any)
        await waitForAppState("sensor history rendered") { self.values(fixture) == [temperature] }
    }
    private func values(_ fixture: GraphFixture) -> [Double] {
        (fixture.view.charts.last?.first?.chartData?.dataSets.first as? LineChartDataSet)?.entries.map(\.y) ?? []
    }
}
