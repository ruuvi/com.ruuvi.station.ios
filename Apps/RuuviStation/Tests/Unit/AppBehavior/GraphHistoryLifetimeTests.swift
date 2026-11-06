import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class GraphHistoryLifetimeTests: XCTestCase {
    func testSupersededHistoryAndLatestReadingCannotReplaceTheNewSensorConfiguration() async {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        let measurements = fixture.measurements
        measurements.settings.chartIntervalSeconds = 60
        var history: CheckedContinuation<Void, Never>?
        var latest: CheckedContinuation<Void, Never>?
        measurements.storage.records = [measurements.record(temperature: 10)]
        measurements.storage.latestOverride = measurements.record(temperature: 10)
        measurements.storage.beforeRead = { await withCheckedContinuation { history = $0 } }
        measurements.storage.beforeLatest = { await withCheckedContinuation { latest = $0 } }
        fixture.interactor.configure(withTag: measurements.sensor.any, andSettings: nil, syncFromCloud: false)
        await waitForAppState("old history suspended") { history != nil && latest != nil }
        measurements.storage.beforeRead = nil
        measurements.storage.beforeLatest = nil
        measurements.storage.records = [measurements.record(temperature: 30)]
        measurements.storage.latestOverride = measurements.record(temperature: 30)
        var sensor = measurements.sensor
        sensor.name = "New configuration"
        fixture.interactor.configure(withTag: sensor.any, andSettings: nil, syncFromCloud: false)
        await waitForAppState("new configuration loaded") {
            fixture.output.loaded == 1 && fixture.output.latest.count == 1
        }
        history?.resume()
        latest?.resume()
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.interactor.ruuviTagData.map { $0.temperature?.value }, [30])
        XCTAssertEqual(fixture.interactor.lastMeasurement?.temperature?.value, 30)
        XCTAssertEqual(fixture.output.latest.count, 1)
        XCTAssertEqual(fixture.output.loaded, 1)
    }

    func testStoppingHistoryDropsAnInflightResponseAndDoesNotRestartItsTimer() async {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        let measurements = fixture.measurements
        measurements.settings.chartIntervalSeconds = 1
        measurements.storage.records = [measurements.record()]
        var release: CheckedContinuation<Void, Never>?
        measurements.storage.beforeRead = { await withCheckedContinuation { release = $0 } }
        fixture.interactor.restartObservingData()
        await waitForAppState("history suspended before close") { release != nil }
        fixture.interactor.stopObservingRuuviTagsData()
        release?.resume()
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.output.loaded, 0)
        XCTAssertTrue(fixture.interactor.ruuviTagData.isEmpty)
    }

    func testRestartingOrStoppingSensorObservationRejectsCallbacksFromInvalidatedSubscriptions() throws {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        let original = fixture.measurements.sensor
        fixture.interactor.restartObservingTags()
        let old = try XCTUnwrap(fixture.reactor.sensors.values.first)
        old(.initial([original.any]))
        var renamed = original
        renamed.name = "Updated name"
        old(.update(renamed.any))
        XCTAssertEqual(fixture.interactor.ruuviTagSensor.name, "Updated name")
        XCTAssertEqual(fixture.output.sensors.map(\.name), ["Updated name"])
        fixture.interactor.restartObservingTags()
        old(.initial([original.any]))
        old(.update(original.any))
        XCTAssertEqual(fixture.interactor.ruuviTagSensor.name, "Updated name")
        let current = try XCTUnwrap(fixture.reactor.sensors.values.first)
        current(.initial([renamed.any]))
        var extra = original
        extra.luid = UUID().uuidString.luid
        extra.macId = "AABBCCDDEEFF".mac
        current(.insert(extra.any))
        current(.update(extra.any))
        XCTAssertEqual(fixture.output.sensors.count, 1)
        fixture.interactor.stopObservingTags()
        current(.update(original.any))
        XCTAssertEqual(fixture.interactor.ruuviTagSensor.name, "Updated name")
        XCTAssertTrue(fixture.reactor.sensors.isEmpty)
    }
}
