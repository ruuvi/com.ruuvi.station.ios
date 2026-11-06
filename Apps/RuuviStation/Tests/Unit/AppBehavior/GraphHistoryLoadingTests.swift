import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class GraphHistoryLoadingTests: XCTestCase {
    func testInitialLoadFiltersRetentionAndPublishesLatestReadingAndAvailableCharts() async throws {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        let measurements = fixture.measurements
        measurements.settings.chartIntervalSeconds = 60
        measurements.settings.dataPruningOffsetHours = 24
        measurements.settings.chartDurationHours = 12
        let latest = measurements.record(temperature: 24)
        measurements.storage.records = [
            measurements.record(date: Date().addingTimeInterval(-25 * 3600), temperature: 99), latest,
        ]
        measurements.storage.latestOverride = latest
        fixture.interactor.configure(withTag: measurements.sensor.any, andSettings: nil, syncFromCloud: false)
        await waitForAppState("initial graph history") {
            fixture.output.loaded == 1 && fixture.output.latest.count == 1
        }
        XCTAssertEqual(fixture.interactor.ruuviTagData.map { $0.temperature?.value }, [24])
        XCTAssertEqual(fixture.interactor.lastMeasurementRecord?.date, latest.date)
        XCTAssertEqual(fixture.output.latest.first?.temperature?.value, 24)
        XCTAssertTrue(fixture.output.variants.first?.contains { $0.type == .temperature } == true)
        XCTAssertEqual(fixture.output.sensors.last?.id, measurements.sensor.id)
        XCTAssertEqual(
            try XCTUnwrap(measurements.storage.requestedFrom).timeIntervalSinceNow, -12 * 3600, accuracy: 3)
    }

    func testDownsamplingStartsAtThresholdAndClampsThePointBudgetWithoutIgnoringShowAll() async {
        for (count, all, requested, expected) in [
            (999, false, 50, 0), (1000, false, 50, 1000),
            (1001, false, 9000, 5000), (1001, true, 3000, 0),
        ] {
            let fixture = GraphHistoryFixture()
            defer { fixture.cleanup() }
            let measurements = fixture.measurements
            measurements.settings.chartIntervalSeconds = 60
            measurements.settings.chartShowAllMeasurements = all
            measurements.flags.graphDownsampleMaximumPoints = requested
            measurements.storage.records = (0..<count).map {
                measurements.record(date: Date().addingTimeInterval(Double($0 - count) * 2), temperature: 20)
            }
            measurements.storage.downsampled = [measurements.record(temperature: 42)]
            fixture.interactor.configure(withTag: measurements.sensor.any, andSettings: nil, syncFromCloud: false)
            await waitForAppState("downsampled graph history") { fixture.output.loaded == 1 }
            XCTAssertEqual(measurements.storage.downsampleCount, expected == 0 ? 0 : 1)
            XCTAssertEqual(fixture.interactor.ruuviTagData.count, expected == 0 ? count : 1)
            if expected > 0 {
                XCTAssertEqual(measurements.storage.requestedPoints, Double(expected))
                XCTAssertEqual(fixture.interactor.ruuviTagData.first?.temperature?.value, 42)
            }
        }
    }

    func testStorageFailureFinishesLoadingAndMissingLatestRecordCreatesNoCharts() async {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        let measurements = fixture.measurements
        measurements.settings.chartIntervalSeconds = 60
        measurements.storage.failure = .ruuviPersistence(.failedToFindRuuviTag)
        fixture.interactor.configure(withTag: measurements.sensor.any, andSettings: nil, syncFromCloud: false)
        await waitForAppState("failed graph load") { fixture.output.loaded == 1 && !fixture.output.errors.isEmpty }
        XCTAssertTrue(fixture.interactor.ruuviTagData.isEmpty)
        XCTAssertEqual(fixture.output.variants, [[]])
        measurements.storage.failure = nil
        measurements.storage.failLatest = true
        fixture.interactor.configure(withTag: measurements.sensor.any, andSettings: nil, syncFromCloud: false)
        await waitForAppState("failed latest reading") { fixture.output.errors.count == 2 }
    }

    func testCloudHistorySyncRequiresACloudSensorAndExistingReading() async {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        let measurements = fixture.measurements
        measurements.settings.chartIntervalSeconds = 60
        measurements.settings.historySyncForEachSensor = true
        var sensor = measurements.sensor
        sensor.isCloudSensor = true
        fixture.interactor.configure(withTag: sensor.any, andSettings: nil, syncFromCloud: true)
        await waitForAppState("empty cloud history") { fixture.output.loaded == 1 }
        XCTAssertEqual(measurements.cloud.count, 0)
        measurements.storage.latestOverride = measurements.record()
        fixture.interactor.configure(withTag: sensor.any, andSettings: nil, syncFromCloud: true)
        await waitForAppState("cloud history synchronized") { measurements.cloud.count == 1 }
        sensor.isCloudSensor = false
        fixture.interactor.configure(withTag: sensor.any, andSettings: nil, syncFromCloud: true)
        await waitForAppState("local history loaded") { fixture.output.loaded == 3 }
        XCTAssertEqual(measurements.cloud.count, 1)
    }

    func testScheduledReadAppendsNewReadingPrunesExpiredHistoryAndStopsOnClose() async throws {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        let measurements = fixture.measurements
        measurements.settings.chartIntervalSeconds = 1
        measurements.settings.chartDurationHours = 1
        let first = measurements.record(date: Date().addingTimeInterval(-10), temperature: 20)
        let second = measurements.record(temperature: 22)
        measurements.storage.latestOverride = first
        measurements.storage.records = [first]
        fixture.interactor.configure(withTag: measurements.sensor.any, andSettings: nil, syncFromCloud: false)
        await waitForAppState("initial scheduled history") { fixture.output.loaded == 1 }
        fixture.interactor.ruuviTagData.insert(
            measurements.record(date: Date().addingTimeInterval(-7200)).measurement, at: 0)
        measurements.storage.recent = [second]
        await waitForAppState("live graph reading") { fixture.output.inserts.count == 1 }
        XCTAssertEqual(fixture.interactor.ruuviTagData.map { $0.temperature?.value }, [20, 22])
        XCTAssertEqual(fixture.output.latest.last?.temperature?.value, 22)
        fixture.interactor.stopObservingRuuviTagsData()
        let reads = measurements.storage.latestCount
        try await Task.sleep(nanoseconds: 1_100_000_000)
        XCTAssertEqual(measurements.storage.latestCount, reads)
    }
}
