import Foundation
import RuuviLocal
import RuuviOntology
import WidgetKit
import XCTest
@testable import RuuviWidgets

@MainActor final class WidgetSnapshotTests: XCTestCase {
    func testAllRecordFieldsSurviveCacheSnapshotRoundTrip() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let original = WidgetSensorRecordSnapshot(from: fixture.record(version: 225))
        let restored = original.toRecord()
        XCTAssertEqual(WidgetSensorRecordSnapshot(from: restored), original)
        var sparse = original
        sparse.temperature = nil
        sparse.voltage = nil
        sparse.accelerationX = nil
        sparse.source = "future-unknown-source"
        sparse.temperatureOffset = nil
        sparse.humidityOffset = nil
        sparse.pressureOffset = nil
        let missing = sparse.toRecord()
        XCTAssertNil(missing.temperature)
        XCTAssertNil(missing.humidity)
        XCTAssertNil(missing.acceleration)
        XCTAssertNil(missing.voltage)
        XCTAssertEqual(missing.source, .unknown)
        XCTAssertEqual(missing.temperatureOffset, 0)
        XCTAssertEqual(missing.humidityOffset, 0)
        XCTAssertEqual(missing.pressureOffset, 0)
    }

    func testCloudOffsetsAndAliasesPersistWithoutDuplicatingLocalSensor() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let record = fixture.record()
        fixture.cache.upsert(
            sensorId: record.luid!.value, name: "Local alias", macId: nil, luid: record.luid!.value,
            record: WidgetSensorRecordSnapshot(from: record), settings: nil)
        let settings = RuuviCloudSensorSettings(displayOrderCodes: ["CO2_PPM"], defaultDisplayOrder: false)
        let dense = fixture.dense(
            record, settings: settings, temperatureOffset: 1, humidityOffset: 10, pressureOffset: 200)
        WidgetCloudSnapshotStore.persist([fixture.dense(nil), dense], in: fixture.cache)
        XCTAssertEqual(fixture.cache.loadAll().count, 1)
        let saved = try XCTUnwrap(fixture.cache.snapshot(matching: record.macId!.value))
        XCTAssertEqual(saved.name, "Local alias")
        XCTAssertEqual(saved.settings?.temperatureOffset, 1)
        XCTAssertEqual(saved.settings?.humidityOffset, 0.1)
        XCTAssertEqual(saved.settings?.pressureOffset, 2)
        XCTAssertEqual(saved.settings?.displayOrder, ["CO2_PPM"])
        let mapped = SensorSettingsStruct.settings(from: dense.sensor.any)
        XCTAssertEqual(mapped.temperatureOffset, 1)
        XCTAssertEqual(mapped.humidityOffset, 0.1)
        XCTAssertEqual(mapped.pressureOffset, 2)
    }

    func testMultiTimelinePreviewAndRefreshPolicyUseTestedSnapshotAndClock() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.store(fixture.record())
        let provider = fixture.multiProvider
        let intent = fixture.multiIntent(["AA:BB:CC:DD:EE:01"])
        let preview: Timeline<MultiSensorWidgetEntry> = await withCheckedContinuation { continuation in
            provider.timeline(for: intent, family: .systemMedium, isPreview: true) {
                continuation.resume(returning: $0)
            }
        }
        XCTAssertEqual(preview.policy, .never)
        XCTAssertTrue(try XCTUnwrap(preview.entries.first).isPreview)
        let live: Timeline<MultiSensorWidgetEntry> = await withCheckedContinuation { continuation in
            provider.timeline(for: intent, family: .systemLarge, isPreview: false) {
                continuation.resume(returning: $0)
            }
        }
        XCTAssertEqual(live.policy, .after(fixture.date.addingTimeInterval(3600)))
        XCTAssertFalse(try XCTUnwrap(live.entries.first).isPreview)
        XCTAssertEqual(live.entries.first?.sensors.first?.record?.temperature?.value, 20)
        XCTAssertEqual(fixture.requests, 0)
    }

    func testMultiCloudAliasUsesNewerLocalReadingAndLocalVisibility() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let record = fixture.record()
        fixture.store(record, order: ["TEMPERATURE_F"])
        let cloud = fixture.dense(
            fixture.record(seconds: -10, source: .ruuviNetwork, temperature: 18),
            settings: RuuviCloudSensorSettings(displayOrderCodes: ["CO2_PPM"], defaultDisplayOrder: false))
        let item = try XCTUnwrap(
            fixture.multiProvider.buildItems(
                from: [record.luid!.value],
                localSnapshots: fixture.cache.loadAll(), cloudSensors: [cloud]
            ).first)
        XCTAssertEqual(item.record?.temperature?.value, 20)
        XCTAssertEqual(item.settings?.displayOrder, ["TEMPERATURE_F"])
        XCTAssertNil(item.cloudSettings)
        let fallback = try XCTUnwrap(
            fixture.multiProvider.buildItems(
                from: [record.macId!.value],
                localSnapshots: fixture.cache.loadAll(), cloudSensors: [fixture.dense(nil)]
            ).first)
        XCTAssertEqual(fallback.record?.temperature?.value, 20)
        let cloudOnly = try XCTUnwrap(
            fixture.multiProvider.buildItems(from: [record.macId!.value], localSnapshots: [], cloudSensors: [cloud])
                .first)
        XCTAssertEqual(cloudOnly.cloudSettings?.displayOrderCodes, ["CO2_PPM"])
    }

    func testCircularNameTruncationPreservesWholeUnicodeCharacters() {
        XCTAssertEqual("🧑‍💻温度🌡️ room".substring(toIndex: 3), "🧑‍💻温度")
        XCTAssertEqual("Sauna".substring(toIndex: 100), "Sauna")
        XCTAssertEqual("Sauna".substring(toIndex: -1), "")
        XCTAssertEqual("".substring(toIndex: 8), "")
    }
}
