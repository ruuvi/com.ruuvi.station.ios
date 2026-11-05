import DGCharts
import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class GraphChartTests: XCTestCase {
    func testHistoryFiltersExpiredAndNonfiniteReadingsAndConvertsTheRequestedUnits() async throws {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        let variant = MeasurementDisplayVariant(type: .temperature, temperatureUnit: .fahrenheit)
        fixture.presenter.createChartModules(from: [variant])
        let now = Date()
        fixture.interactor.ruuviTagData = [
            fixture.measurements.record(date: now.addingTimeInterval(-200000), temperature: 99).measurement,
            fixture.measurements.record(date: now.addingTimeInterval(-10), temperature: 10).measurement,
            fixture.measurements.record(date: now, temperature: 20).measurement,
            fixture.measurements.record(date: now, temperature: .nan).measurement,
            fixture.measurements.record(date: Date(timeIntervalSince1970: .infinity)).measurement,
        ]
        fixture.presenter.interactorDidFinishLoadingHistory()
        fixture.presenter.interactorDidUpdate(sensor: fixture.measurements.sensor.any)
        await waitForAppState("temperature history") { fixture.view.charts.last?.first?.chartData?.entryCount == 2 }
        let chart = try XCTUnwrap(fixture.view.charts.last?.first)
        let data = try XCTUnwrap(chart.chartData?.dataSets.first as? LineChartDataSet)
        XCTAssertEqual(chart.variant, variant)
        XCTAssertEqual(data.entries.map { $0.y.rounded() }, [50, 68])
        XCTAssertEqual(
            data.entries.map(\.x), [now.addingTimeInterval(-10).timeIntervalSince1970, now.timeIntervalSince1970])
        XCTAssertEqual(fixture.view.hasData.last, true)
        let count = fixture.view.charts.count
        fixture.presenter.interactorDidFinishLoadingHistory()
        fixture.presenter.interactorDidUpdate(sensor: fixture.measurements.sensor.any)
        await flushAppBindings()
        XCTAssertEqual(fixture.view.charts.count, count, "Unchanged history must reuse the rendered chart")
    }

    func testLiveMeasurementsWaitForScrollingToEndAndUpdateLatestValues() async throws {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        let variant = MeasurementDisplayVariant(type: .temperature, temperatureUnit: .celsius)
        fixture.presenter.createChartModules(from: [variant])
        let first = fixture.measurements.record(temperature: 21).measurement
        let second = fixture.measurements.record(date: Date().addingTimeInterval(1), temperature: 22).measurement
        fixture.presenter.viewDidStartScrolling()
        fixture.interactor.ruuviTagData = [first, second]
        fixture.presenter.insertMeasurements([first])
        fixture.presenter.insertMeasurements([second])
        XCTAssertTrue(fixture.view.appended.isEmpty)
        fixture.presenter.viewDidEndScrolling()
        XCTAssertEqual(fixture.view.appended.count, 1)
        XCTAssertEqual(fixture.view.appended.first?[variant]?.map(\.y), [21, 22])
        XCTAssertEqual(fixture.view.firstEntries, [false])
        XCTAssertEqual(try XCTUnwrap(fixture.view.latest.last?[variant]??.y), 22)
        XCTAssertEqual(fixture.view.hasData.last, true)
        fixture.presenter.viewDidEndScrolling()
        XCTAssertEqual(fixture.view.appended.count, 1)
        fixture.interactor.ruuviTagData = [first]
        fixture.presenter.insertMeasurements([first])
        XCTAssertEqual(fixture.view.firstEntries.last, true)
        await flushAppBindings()
    }

    func testPendingScrollSelectsTheVisibleVariantAndEmptyHistoryShowsAnEmptyState() async {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        fixture.presenter.createChartModules(from: [])
        fixture.presenter.scroll(to: .temperature, variant: nil)
        XCTAssertTrue(fixture.view.scrolls.isEmpty)
        let celsius = MeasurementDisplayVariant(type: .temperature, temperatureUnit: .celsius)
        let fahrenheit = MeasurementDisplayVariant(type: .temperature, temperatureUnit: .fahrenheit)
        fixture.measurements.snapshot.displayData.measurementVisibility = .init(
            availableVariants: [celsius, fahrenheit], visibleVariants: [fahrenheit])
        fixture.presenter.createChartModules(from: [celsius, fahrenheit])
        XCTAssertEqual(fixture.view.modules.last, [fahrenheit])
        XCTAssertEqual(fixture.view.scrolls, [fahrenheit])
        fixture.presenter.scroll(to: .temperature, variant: fahrenheit)
        XCTAssertEqual(fixture.view.scrolls, [fahrenheit, fahrenheit])
        fixture.presenter.scroll(to: .co2, variant: nil)
        XCTAssertEqual(fixture.view.scrolls.count, 2)
        fixture.presenter.interactorDidFinishLoadingHistory()
        fixture.presenter.interactorDidUpdate(sensor: fixture.measurements.sensor.any)
        await waitForAppState("empty graph") { fixture.view.charts.last?.isEmpty == true }
        XCTAssertEqual(fixture.view.hasData.last, false)
    }

    func testCalibrationChangesReloadHistoryAndDeletedSettingsRestoreRawValues() async throws {
        let fixture = GraphFixture()
        defer { fixture.cleanup() }
        let variant = MeasurementDisplayVariant(type: .temperature, temperatureUnit: .celsius)
        fixture.presenter.createChartModules(from: [variant])
        fixture.presenter.viewDidLoad()
        let sensor = fixture.measurements.sensor
        let calibration = SensorSettingsStruct(
            luid: sensor.luid, macId: sensor.macId, temperatureOffset: 5, humidityOffset: nil, pressureOffset: nil)
        fixture.reactor.sendSettings(sensor, .initial([calibration]))
        fixture.interactor.ruuviTagData = [fixture.measurements.record(temperature: 20).measurement]
        fixture.presenter.interactorDidFinishLoadingHistory()
        fixture.presenter.interactorDidUpdate(sensor: sensor.any)
        await waitForAppState("calibrated graph") { self.values(fixture) == [25] }
        fixture.reactor.sendSettings(sensor, .update(calibration))
        fixture.reactor.sendSettings(sensor, .insert(calibration))
        fixture.reactor.sendSettings(sensor, .delete(calibration))
        XCTAssertEqual(fixture.interactor.dataStarts, 3)
        fixture.interactor.ruuviTagData = [fixture.measurements.record(temperature: 21).measurement]
        fixture.presenter.interactorDidFinishLoadingHistory()
        fixture.presenter.interactorDidUpdate(sensor: sensor.any)
        await waitForAppState("cleared calibration") { self.values(fixture) == [21] }
        fixture.presenter.interactorDidError(.bluetooth(.disconnected))
        XCTAssertEqual(fixture.errors.errors.count, 1)
    }

    private func values(_ fixture: GraphFixture) -> [Double] {
        (fixture.view.charts.last?.first?.chartData?.dataSets.first as? LineChartDataSet)?.entries.map(\.y) ?? []
    }
}
