import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology
import WidgetKit
import XCTest
@testable import RuuviWidgets

@MainActor final class WidgetTimelineTests: XCTestCase {
    func testSignedOutAndFreshCacheTimelinesNeverFetchCloud() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.store(fixture.record())
        let provider = fixture.provider
        let offline = await timeline(provider, fixture.intent())
        XCTAssertEqual(offline.entries.first?.record?.temperature?.value, 20)
        XCTAssertEqual(fixture.requests, 0)
        fixture.authorize()
        fixture.cloudCache.markFresh()
        let cached = await timeline(provider, fixture.intent())
        XCTAssertEqual(cached.entries.first?.tag.displayString, "Local name")
        XCTAssertEqual(fixture.requests, 0)
        XCTAssertEqual(cached.policy, .after(fixture.date.addingTimeInterval(3600)))
    }

    func testPreviewAndUnconfiguredTimelinesCompleteWithoutNetwork() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        let provider = fixture.provider
        let preview = await timeline(provider, fixture.intent(), preview: true)
        XCTAssertEqual(preview.policy, .never)
        XCTAssertTrue(try XCTUnwrap(preview.entries.first).isPreview)
        let empty = await timeline(provider, fixture.intent(id: nil))
        XCTAssertNil(empty.entries.first?.record)
        XCTAssertEqual(empty.policy, .atEnd)
        XCTAssertEqual(fixture.requests, 0)
        fixture.store(fixture.record(), order: ["TEMPERATURE_F"])
        let snapshot = await timeline(provider, fixture.intent(), preview: true)
        XCTAssertEqual(snapshot.entries.first?.tag.displayString, "Local name")
        XCTAssertEqual(snapshot.entries.first?.settings?.displayOrder, ["TEMPERATURE_F"])
        XCTAssertEqual(fixture.requests, 0)
    }

    func testNewerCloudRecordUpdatesTimelineAndCacheWithoutLosingLocalNameOrOrder() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        fixture.store(fixture.record(), order: ["HUMIDITY_0", "TEMPERATURE_F"])
        fixture.response = [fixture.dense(fixture.record(seconds: 10, source: .ruuviNetwork, temperature: 24))]
        let provider = fixture.provider
        let result = await timeline(provider, fixture.intent())
        let entry = try XCTUnwrap(result.entries.first)
        XCTAssertEqual(entry.record?.temperature?.value, 24)
        XCTAssertEqual(entry.tag.displayString, "Local name")
        XCTAssertEqual(entry.settings?.displayOrder, ["HUMIDITY_0", "TEMPERATURE_F"])
        XCTAssertEqual(fixture.cache.loadAll().first?.name, "Local name")
        XCTAssertEqual(fixture.cache.loadAll().first?.record?.temperature, 24)
        XCTAssertTrue(fixture.cloudCache.isFresh(intervalMinutes: 60))
        XCTAssertEqual(fixture.requests, 1)
    }

    func testOlderOrSameTimestampCloudRecordCannotReplaceBluetoothReading() async throws {
        for seconds: Double in [-10, 0] {
            let fixture = try WidgetFixture()
            defer { fixture.clean() }
            fixture.authorize()
            fixture.store(fixture.record(temperature: 22))
            fixture.response = [fixture.dense(fixture.record(seconds: seconds, source: .ruuviNetwork, temperature: 18))]
            let provider = fixture.provider
            let result = await timeline(provider, fixture.intent())
            XCTAssertEqual(result.entries.first?.record?.temperature?.value, 22)
            XCTAssertEqual(fixture.cache.loadAll().first?.record?.temperature, 22)
        }
    }

    func testFailedManualRefreshFallsBackLocallyAndRemainsRetryable() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        fixture.store(fixture.record())
        fixture.cloudCache.markFresh()
        fixture.model.forceRefreshWidget(true)
        fixture.error = WidgetFailure.offline
        let provider = fixture.provider
        let fallback = await timeline(provider, fixture.intent())
        XCTAssertEqual(fallback.entries.first?.record?.temperature?.value, 20)
        XCTAssertTrue(fixture.model.shouldForceRefresh())
        XCTAssertEqual(fixture.requests, 1)
        fixture.error = nil
        fixture.response = [fixture.dense(fixture.record(seconds: 20, source: .ruuviNetwork, temperature: 25))]
        let recovered = await timeline(provider, fixture.intent())
        XCTAssertEqual(recovered.entries.first?.record?.temperature?.value, 25)
        XCTAssertEqual(fixture.requests, 2)
        XCTAssertFalse(fixture.model.shouldForceRefresh())
    }

    func testCloudFailureWithoutLocalDataReturnsEmptyTimeline() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        fixture.error = WidgetFailure.offline
        let provider = fixture.provider
        let result = await timeline(provider, fixture.intent())
        XCTAssertNil(result.entries.first?.record)
        XCTAssertEqual(result.policy, .atEnd)
        XCTAssertEqual(fixture.requests, 1)
        XCTAssertFalse(fixture.cloudCache.isFresh(intervalMinutes: 60))
    }

    func testCloudOnlySensorAndLocalIdentifierSelectionResolveCorrectly() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        let record = fixture.record(source: .ruuviNetwork)
        fixture.response = [fixture.dense(record)]
        let provider = fixture.provider
        let result = await timeline(provider, fixture.intent(id: record.luid?.value))
        XCTAssertEqual(result.entries.first?.record?.macId?.value, record.macId?.value)
        XCTAssertEqual(result.entries.first?.tag.displayString, "Cloud name")
        XCTAssertEqual(fixture.cache.loadAll().count, 1)
    }

    func testFetchFiltersMissingRecordsAndDuplicateSensorsKeepNewestRecord() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        fixture.response = [
            fixture.dense(nil, id: "missing"),
            fixture.dense(fixture.record(seconds: -10, source: .ruuviNetwork, temperature: 18)),
            fixture.dense(fixture.record(source: .ruuviNetwork, temperature: 22)),
        ]
        let records = await fixture.model.fetchRuuviTagsAsync()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.record?.temperature?.value, 22)
        let items = fixture.multiProvider.buildItems(
            from: ["AA:BB:CC:DD:EE:01"], localSnapshots: [], cloudSensors: fixture.response)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.record?.temperature?.value, 22)
    }

    func testUnauthorizedAndNoCloudSensorsSkipFetch() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let unauthorized = await fixture.model.fetchRuuviTagsAsync()
        XCTAssertTrue(unauthorized.isEmpty)
        fixture.authorize(cloudSensors: false)
        let localOnly = await fixture.model.fetchRuuviTagsAsync()
        XCTAssertTrue(localOnly.isEmpty)
        XCTAssertEqual(fixture.requests, 0)
    }

    func testMultiSensorTimelinePreservesSelectionOrderAndUsesFreshCache() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        fixture.store(fixture.record(mac: "AA:BB:CC:DD:EE:01", temperature: 20), name: "First")
        fixture.store(fixture.record(mac: "AA:BB:CC:DD:EE:02", temperature: 25), name: "Second")
        fixture.cloudCache.markFresh()
        let provider = fixture.multiProvider
        let entry = await provider.makeEntry(
            for: fixture.multiIntent(["AA:BB:CC:DD:EE:02", "missing", "AA:BB:CC:DD:EE:01"]))
        XCTAssertEqual(entry.sensors.map(\.name), ["Second", "First"])
        XCTAssertEqual(entry.sensors.map { $0.record?.temperature?.value }, [25, 20])
        XCTAssertFalse(entry.isPreview)
        XCTAssertEqual(fixture.requests, 0)
    }

    func testMultiSensorCloudFallbackAndEmptySelection() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        let provider = fixture.multiProvider
        let empty = await provider.makeEntry(for: fixture.multiIntent([]))
        XCTAssertTrue(empty.sensors.isEmpty)
        XCTAssertEqual(fixture.requests, 0)
        fixture.response = [fixture.dense(fixture.record(version: 6, source: .ruuviNetwork))]
        let loaded = await provider.makeEntry(for: fixture.multiIntent(["AA:BB:CC:DD:EE:01"]))
        XCTAssertEqual(loaded.sensors.count, 1)
        XCTAssertEqual(loaded.sensors.first?.deviceType, .ruuviAir)
        XCTAssertEqual(fixture.requests, 1)
        fixture.model.forceRefreshWidget(true)
        fixture.error = WidgetFailure.offline
        let fallback = await provider.makeEntry(for: fixture.multiIntent(["AA:BB:CC:DD:EE:01"]))
        XCTAssertEqual(fallback.sensors.first?.record?.temperature?.value, 20)
        let missing = await provider.makeEntry(for: fixture.multiIntent(["missing"]))
        XCTAssertTrue(missing.sensors.isEmpty)
    }

    func testMultiSnapshotIsImmediateAndNeverFetchesCloud() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        fixture.store(fixture.record(), order: ["TEMPERATURE_C"])
        let provider = fixture.multiProvider
        var snapshot: MultiSensorWidgetEntry?
        provider.snapshot(for: fixture.multiIntent(["AA:BB:CC:DD:EE:01"]), family: .systemMedium) { snapshot = $0 }
        XCTAssertEqual(try XCTUnwrap(snapshot).sensors.first?.settings?.displayOrder, ["TEMPERATURE_C"])
        XCTAssertTrue(try XCTUnwrap(snapshot).isPreview)
        provider.snapshot(for: fixture.multiIntent(["missing"]), family: .systemLarge) { snapshot = $0 }
        XCTAssertFalse(try XCTUnwrap(snapshot).sensors.isEmpty)
        XCTAssertEqual(fixture.requests, 0)
    }

    private func timeline(_ provider: WidgetProvider, _ intent: RuuviTagSelectionIntent, preview: Bool = false) async
        -> Timeline<WidgetEntry>
    {
        await withCheckedContinuation { continuation in
            provider.timeline(for: intent, isPreview: preview) { continuation.resume(returning: $0) }
        }
    }
}

enum WidgetFailure: Error { case offline }
