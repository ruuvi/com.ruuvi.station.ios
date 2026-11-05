import Foundation
import Intents
import RuuviOntology
import XCTest
@testable import RuuviWidgets

@MainActor final class WidgetIntentTests: XCTestCase {
    func testEverySelectionSlotOffersCachedSensorsWithoutNetworkWhenSignedOut() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.store(fixture.record(), name: "Kitchen")
        let handler = RuuviWidgetIntentHandler(
            viewModel: fixture.model, localCache: fixture.cache, cloudCache: fixture.cloudCache)
        typealias Completion = (INObjectCollection<RuuviWidgetTag>?, Error?) -> Void
        let single = fixture.intent()
        let multi = fixture.multiIntent([])
        let calls: [(@escaping Completion) -> Void] = [
            { handler.provideRuuviWidgetTagOptionsCollection(for: single, with: $0) },
            { handler.provideSensor1OptionsCollection(for: multi, with: $0) },
            { handler.provideSensor2OptionsCollection(for: multi, with: $0) },
            { handler.provideSensor3OptionsCollection(for: multi, with: $0) },
            { handler.provideSensor4OptionsCollection(for: multi, with: $0) },
            { handler.provideSensor5OptionsCollection(for: multi, with: $0) },
            { handler.provideSensor6OptionsCollection(for: multi, with: $0) },
        ]
        for call in calls {
            var callbacks = 0
            call { collection, error in
                callbacks += 1
                XCTAssertNil(error)
                XCTAssertEqual(
                    collection?.allItems.map(\.identifier),
                    [WidgetConfigurationSelection.noneIdentifier, "AA:BB:CC:DD:EE:01"])
                XCTAssertEqual(collection?.allItems.last?.displayString, "Kitchen")
                XCTAssertEqual(collection?.allItems.last?.deviceType, .ruuviTag)
            }
            XCTAssertEqual(callbacks, 1)
        }
        XCTAssertEqual(fixture.requests, 0)
    }

    func testFreshAuthorizedCacheAndEmptyOfflineCacheAvoidNetwork() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let handler = RuuviWidgetIntentHandler(
            viewModel: fixture.model, localCache: fixture.cache, cloudCache: fixture.cloudCache)
        let empty = try await options(handler)
        XCTAssertTrue(empty.allItems.isEmpty)
        fixture.authorize()
        fixture.store(fixture.record(version: 6))
        fixture.cloudCache.markFresh()
        let cached = try await options(handler)
        XCTAssertEqual(cached.allItems.last?.deviceType, .ruuviAir)
        XCTAssertEqual(fixture.requests, 0)
    }

    func testCloudDiscoveryMergesLocalSensorsAndPreservesLocalNamesWithoutDuplicates() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        fixture.store(fixture.record(), name: "Local kitchen")
        fixture.store(fixture.record(mac: "AA:BB:CC:DD:EE:02"), name: "Bluetooth only")
        fixture.response = [
            fixture.dense(fixture.record(version: 6, source: .ruuviNetwork)),
            fixture.dense(
                fixture.record(version: 6, source: .ruuviNetwork, mac: "AA:BB:CC:DD:EE:03"), id: "AA:BB:CC:DD:EE:03",
                name: "Cloud only"),
        ]
        let handler = RuuviWidgetIntentHandler(
            viewModel: fixture.model, localCache: fixture.cache, cloudCache: fixture.cloudCache,
            scheduleFallback: { _ in })
        let result = try await options(handler)
        XCTAssertEqual(result.allItems.count, 4)
        XCTAssertEqual(
            result.allItems.map(\.displayString).dropFirst(), ["Local kitchen", "Cloud only", "Bluetooth only"])
        XCTAssertEqual(Set(result.allItems.compactMap(\.identifier)).count, 4)
        XCTAssertEqual(fixture.cache.snapshot(matching: "AA:BB:CC:DD:EE:01")?.name, "Local kitchen")
        XCTAssertTrue(fixture.cloudCache.isFresh(intervalMinutes: 60))
    }

    func testCloudFailureUsesLocalOptionsAndDoesNotMarkCacheFresh() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        fixture.store(fixture.record())
        fixture.error = WidgetFailure.offline
        let handler = RuuviWidgetIntentHandler(
            viewModel: fixture.model, localCache: fixture.cache, cloudCache: fixture.cloudCache,
            scheduleFallback: { _ in })
        let result = try await options(handler)
        XCTAssertEqual(result.allItems.count, 2)
        XCTAssertEqual(result.allItems.last?.displayString, "Local name")
        XCTAssertFalse(fixture.cloudCache.isFresh(intervalMinutes: 60))
    }

    func testTimeoutCompletesOnceWhileLateCloudResponseStillUpdatesCache() async throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.authorize()
        fixture.store(fixture.record())
        fixture.response = [fixture.dense(fixture.record(seconds: 20, source: .ruuviNetwork, temperature: 26))]
        let started = expectation(description: "Cloud request started")
        let completed = expectation(description: "Fallback returned")
        completed.assertForOverFulfill = true
        let gate = WidgetTestGate()
        fixture.beforeResponse = {
            started.fulfill(); await gate.wait()
        }
        var fallback: (() -> Void)?
        let handler = RuuviWidgetIntentHandler(
            viewModel: fixture.model, localCache: fixture.cache, cloudCache: fixture.cloudCache,
            scheduleFallback: { fallback = $0 })
        var callbacks = 0
        handler.provideWidgetTagOptionsCollection { collection, error in
            callbacks += 1
            XCTAssertNil(error)
            XCTAssertEqual(collection?.allItems.last?.displayString, "Updated while waiting")
            completed.fulfill()
        }
        await fulfillment(of: [started], timeout: 5)
        fixture.store(fixture.record(), name: "Updated while waiting")
        try XCTUnwrap(fallback)()
        await fulfillment(of: [completed], timeout: 5)
        gate.open()
        let persisted = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                fixture.cache.loadAll().first?.record?.temperature == 26
            }, object: nil)
        await fulfillment(of: [persisted], timeout: 5)
        XCTAssertEqual(callbacks, 1)
        XCTAssertTrue(fixture.cloudCache.isFresh(intervalMinutes: 60))
    }

    func testSensorMeasurementOptionsUseSelectedDeviceAndCachedRecordCapabilities() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        var record = fixture.record(version: 225)
        record.co2 = nil
        fixture.store(record)
        let handler = RuuviWidgetIntentHandler(
            viewModel: fixture.model, localCache: fixture.cache, cloudCache: fixture.cloudCache)
        let intent = fixture.intent()
        intent.ruuviWidgetTag?.deviceType = .ruuviAir
        var identifiers = [String]()
        handler.provideSensorSelectionOptionsCollection(for: intent) { collection, error in
            XCTAssertNil(error)
            identifiers = collection?.allItems.compactMap(\.identifier) ?? []
        }
        XCTAssertTrue(identifiers.contains("TEMPERATURE_C"))
        XCTAssertTrue(identifiers.contains("PM25_MGM3"))
        XCTAssertFalse(identifiers.contains("CO2_PPM"))
        XCTAssertFalse(identifiers.contains("AQI_INDEX"))
        XCTAssertEqual(fixture.requests, 0)
    }

    private func options(_ handler: RuuviWidgetIntentHandler) async throws -> INObjectCollection<RuuviWidgetTag> {
        try await withCheckedThrowingContinuation { continuation in
            handler.provideWidgetTagOptionsCollection { collection, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let collection {
                    continuation.resume(returning: collection)
                } else {
                    continuation.resume(throwing: WidgetFailure.offline)
                }
            }
        }
    }
}

@MainActor final class WidgetTestGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var opened = false
    func wait() async {
        guard !opened else { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func open() { opened = true; continuation?.resume(); continuation = nil }
}
