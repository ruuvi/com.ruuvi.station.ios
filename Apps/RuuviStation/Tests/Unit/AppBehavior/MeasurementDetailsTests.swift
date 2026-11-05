import DGCharts
import Foundation
import RuuviLocal
import RuuviOntology
import XCTest
@testable import station

@MainActor final class MeasurementDetailsTests: XCTestCase {
    func testHistoryIsSortedFiniteAndUsesTheSelectedVariant() async throws {
        let fixture = MeasurementFixture()
        let now = Date()
        fixture.storage.records = [
            fixture.record(date: now, temperature: 20),
            fixture.record(date: now.addingTimeInterval(-30), temperature: 10),
            fixture.record(date: now.addingTimeInterval(-20), temperature: .nan),
            fixture.record(date: Date(timeIntervalSince1970: .infinity), temperature: 50),
        ]
        let variant = MeasurementDisplayVariant(type: .temperature, temperatureUnit: .fahrenheit)
        let presenter = fixture.presenter(variant: variant)
        defer { presenter.stop() }
        presenter.viewDidLoad()
        presenter.start()
        await waitForAppState("history chart") { !fixture.view.charts.isEmpty }
        XCTAssertEqual(fixture.view.values.map { $0.rounded() }, [50, 68])
        XCTAssertEqual(fixture.view.units.last, "°F")
        XCTAssertEqual(fixture.storage.readCount, 1, "Starting an active presenter must not duplicate work")
        XCTAssertEqual(fixture.cloud.count, 0)
        XCTAssertEqual(fixture.view.noData.last, false)
        let cutoff = try XCTUnwrap(fixture.storage.requestedFrom)
        XCTAssertEqual(now.timeIntervalSince(cutoff), 48 * 3600, accuracy: 2)
        presenter.didTapGraph()
        XCTAssertEqual(fixture.output.variant, variant)
        XCTAssertEqual(fixture.output.sensorID, fixture.sensor.id)
    }

    func testIncomingReadingsAppendOnceAndStopDetachesObservers() async {
        let fixture = MeasurementFixture()
        let now = Date()
        let original = fixture.record(date: now.addingTimeInterval(-10), temperature: 10)
        let newer = fixture.record(date: now, temperature: 20)
        fixture.storage.records = [original]
        fixture.storage.recent = [newer, original, newer]
        let presenter = fixture.presenter()
        defer { presenter.stop() }
        presenter.start()
        await waitForAppState("initial chart") { !fixture.view.charts.isEmpty }
        fixture.snapshot.latestRawRecord = newer
        await waitForAppState("live chart reading") { !fixture.view.appended.isEmpty }
        XCTAssertEqual(fixture.view.appended.map(\.y), [20])
        presenter.stop()
        let reads = fixture.storage.latestCount
        fixture.snapshot.latestRawRecord = fixture.record(date: now.addingTimeInterval(10), temperature: 30)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(fixture.storage.latestCount, reads)
        XCTAssertEqual(fixture.view.appended.count, 1)
    }

    func testEmptyHistoryCanRecoverWhenTheFirstReadingArrives() async {
        let fixture = MeasurementFixture()
        let presenter = fixture.presenter()
        defer { presenter.stop() }
        presenter.start()
        await waitForAppState("empty state") { fixture.view.noData.last == true }
        let first = fixture.record()
        fixture.storage.records = [first]
        fixture.snapshot.latestRawRecord = first
        await waitForAppState("first measurement") { fixture.view.values == [20] }
        XCTAssertEqual(fixture.view.noData.last, false)
    }

    func testClosingWhileReadFailsDoesNotUpdateTheDismissedView() async {
        let fixture = MeasurementFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.storage.beforeRead = { await withCheckedContinuation { release = $0 } }
        let presenter = fixture.presenter()
        presenter.start()
        await waitForAppState("suspended history") { release != nil }
        presenter.stop()
        fixture.storage.failure = .ruuviPersistence(.failedToFindRuuviTag)
        release?.resume()
        try? await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertTrue(fixture.view.noData.isEmpty, "A late error must not mutate a dismissed screen")
        XCTAssertTrue(fixture.view.charts.isEmpty)
    }

    func testOldReadCannotReplaceANewerMeasurementSelection() async {
        let fixture = MeasurementFixture()
        fixture.storage.records = [fixture.record(co2: 400)]
        var release: CheckedContinuation<Void, Never>?
        fixture.storage.beforeRead = { await withCheckedContinuation { release = $0 } }
        let presenter = fixture.presenter()
        defer { presenter.stop() }
        presenter.start()
        await waitForAppState("suspended first read") { release != nil }
        fixture.storage.beforeRead = nil
        fixture.storage.records = [fixture.record(co2: 900)]
        presenter.didTapMeasurement(fixture.indicator(.init(type: .co2)))
        await waitForAppState("new selection") { fixture.view.values == [900] }
        release?.resume()
        try? await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertEqual(fixture.view.values, [900], "The superseded response contains stale CO₂")
    }

    func testDownsamplingHonorsPreferenceThresholdAndPointLimit() async {
        for (count, showAll, points, expected) in [
            (999, false, 50, 0), (1000, false, 50, 1000),
            (1100, false, 9000, 5000), (1100, true, 3000, 0),
        ] {
            let fixture = MeasurementFixture()
            fixture.settings.chartShowAllMeasurements = showAll
            fixture.flags.graphDownsampleMaximumPoints = points
            let now = Date()
            fixture.storage.records = (0..<count).map {
                fixture.record(date: now.addingTimeInterval(Double($0 - count) * 3))
            }
            fixture.storage.downsampled = [fixture.record(temperature: 42)]
            let presenter = fixture.presenter()
            presenter.start()
            await waitForAppState("downsampling decision") { !fixture.view.charts.isEmpty }
            XCTAssertEqual(fixture.storage.downsampleCount, expected == 0 ? 0 : 1)
            if expected > 0 {
                XCTAssertEqual(fixture.storage.requestedPoints, Double(expected))
                XCTAssertEqual(fixture.view.values, [42])
            } else {
                XCTAssertEqual(fixture.view.values.count, count)
            }
            presenter.stop()
        }
    }

    func testCloudRefreshReloadsPersistedHistoryAndFailureKeepsExistingChart() async {
        for failure in [false, true] {
            let fixture = MeasurementFixture(cloud: true)
            fixture.storage.records = [fixture.record(temperature: 10)]
            fixture.cloud.failure = failure
            fixture.cloud.beforeSync = { fixture.storage.records = [fixture.record(temperature: 20)] }
            let presenter = fixture.presenter()
            presenter.start()
            await waitForAppState("cloud sync") { fixture.cloud.count == 1 }
            await waitForAppState("post-sync chart") { fixture.view.values == [failure ? 10 : 20] }
            XCTAssertEqual(fixture.storage.readCount, failure ? 1 : 2)
            presenter.stop()
        }
    }

    func testVisibleVariantAlertBoundsAndUnitChangesUpdateTheSameChart() async throws {
        let fixture = MeasurementFixture()
        let fahrenheit = MeasurementDisplayVariant(type: .temperature, temperatureUnit: .fahrenheit)
        fixture.snapshot.displayData.measurementVisibility = .init(
            availableVariants: [fahrenheit], visibleVariants: [fahrenheit]
        )
        fixture.snapshot.displayData.indicatorGrid = .init(indicators: [
            fixture.indicator(.init(type: .co2)), fixture.indicator(fahrenheit),
        ])
        fixture.snapshot.updateAlertConfig(
            for: .temperature,
            config: .init(
                isActive: true, isFiring: false, mutedTill: nil, lowerBound: 10, upperBound: 30
            ))
        fixture.storage.records = [fixture.record()]
        let presenter = fixture.presenter(variant: .init(type: .temperature, temperatureUnit: .celsius))
        defer { presenter.stop() }
        presenter.start()
        await waitForAppState("visible variant") { fixture.view.values.map { $0.rounded() } == [68] }
        await waitForAppState("filtered indicators") { !fixture.view.measurements.isEmpty }
        XCTAssertEqual(fixture.view.measurements.last??.indicatorGrid?.indicators.map(\.variant), [fahrenheit])
        XCTAssertEqual(try XCTUnwrap(fixture.view.charts.last?.lowerAlertValue), 50, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(fixture.view.charts.last?.upperAlertValue), 86, accuracy: 0.001)
        let chartCount = fixture.view.charts.count
        fixture.settings.temperatureUnit = .kelvin
        NotificationCenter.default.post(name: .TemperatureUnitDidChange, object: fixture.settings)
        await waitForAppState("unit notification") { fixture.view.charts.count > chartCount }
        XCTAssertEqual(fixture.view.values.map { $0.rounded() }, [68], "An explicit variant retains its unit")
        fixture.snapshot.updateAlertConfig(for: .temperature, config: .inactive)
        await waitForAppState("disabled range") { fixture.view.charts.last?.lowerAlertValue == nil }
        XCTAssertNil(fixture.view.charts.last?.upperAlertValue)
    }

    func testReadFailureAndInvalidMeasurementsProduceAnEmptyState() async {
        for fails in [false, true] {
            let fixture = MeasurementFixture()
            fixture.storage.records = [fixture.record(temperature: .nan)]
            if fails { fixture.storage.failure = .ruuviPersistence(.failedToFindRuuviTag) }
            let presenter = fixture.presenter()
            presenter.start()
            await waitForAppState("no valid data") { fixture.view.noData.last == true }
            XCTAssertTrue(fixture.view.charts.isEmpty)
            presenter.stop()
        }
    }
}
