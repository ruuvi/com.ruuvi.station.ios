import RuuviLocal
import RuuviOntology
import RuuviReactor
import RuuviService
import UIKit
import XCTest
@testable import station

@MainActor final class SensorDataLifecycleTests: XCTestCase {
    func testSlowInitialReadEventuallyAppearsWithoutOverwritingANewerLiveReading() async throws {
        for newerLive in [false, true] {
            let fixture = SensorDataFixture()
            defer { fixture.cleanup() }
            let sensor = fixture.sensor()
            let old = fixture.measurements.record(date: Date(timeIntervalSince1970: 100), temperature: 20)
            fixture.measurements.storage.latestOverride = old
            var release: CheckedContinuation<Void, Never>?
            fixture.measurements.storage.beforeLatest = { await withCheckedContinuation { release = $0 } }
            fixture.service.startObservingSensors()
            fixture.send(.initial([sensor.any]))
            await waitForAppState("initial read pending") { release != nil }
            try? await Task.sleep(nanoseconds: 200_000_000)
            if newerLive {
                let live = fixture.measurements.record(date: Date(timeIntervalSince1970: 200), temperature: 30)
                fixture.reactor.sendLatest(sensor, .update(live.any))
                await waitForAppState("live reading") {
                    fixture.service.getSnapshot(for: sensor.id)?.lastUpdated == live.date
                }
            }
            release?.resume()
            await waitForAppState("stored or live reading") {
                fixture.service.getSnapshot(for: sensor.id)?.latestRawRecord?.temperature?.value
                    == (newerLive ? 30 : 20)
            }
            await flushAppBindings()
            XCTAssertEqual(
                fixture.service.getSnapshot(for: sensor.id)?.latestRawRecord?.temperature?.value, newerLive ? 30 : 20)
        }
    }

    func testSensorInsertedWhileInitialReadIsPendingRemainsInTheDashboard() async {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        let first = fixture.sensor("A")
        let second = fixture.sensor("B")
        var release: CheckedContinuation<Void, Never>?
        fixture.measurements.storage.beforeLatest = {
            if release == nil { await withCheckedContinuation { release = $0 } }
        }
        fixture.service.startObservingSensors()
        fixture.send(.initial([first.any]))
        await waitForAppState("first read pending") { release != nil }
        fixture.send(.insert(second.any))
        fixture.measurements.storage.beforeLatest = nil
        release?.resume()
        await waitForAppState("both snapshots") { fixture.service.getAllSnapshots().count == 2 }
        await flushAppBindings()
        XCTAssertEqual(Set(fixture.service.getAllSnapshots().map(\.id)), [first.id, second.id])
        XCTAssertEqual(Set(fixture.service.getAllSensors().map(\.id)), [first.id, second.id])
    }

    func testStoppingPreventsPendingReadAndUnitChangesFromPublishingAndReleasesTheService() async {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.sensor()
        var release: CheckedContinuation<Void, Never>?
        fixture.measurements.storage.beforeLatest = { await withCheckedContinuation { release = $0 } }
        fixture.service.startObservingSensors()
        fixture.send(.initial([sensor.any]))
        await waitForAppState("read pending") { release != nil }
        fixture.service.stopObservingSensors()
        let count = fixture.delegate.lists.count
        autoreleasepool {
            var measurement = fixture.measurements.measurement
            measurement.units = .init(
                temperatureUnit: .fahrenheit, humidityUnit: .percent, pressureUnit: .hectopascals)
        }
        weak var service = fixture.service
        fixture.service = nil
        XCTAssertNil(service)
        release?.resume()
        await flushAppBindings()
        await flushAppBindings()
        XCTAssertEqual(fixture.delegate.lists.count, count)
        XCTAssertTrue(fixture.reactor.sensors.isEmpty)
        XCTAssertTrue(fixture.reactor.settings.isEmpty)
        XCTAssertTrue(fixture.reactor.latest.isEmpty)
    }

    func testDeletingSensorDuringImageReadDoesNotPublishAnOrphanedSnapshot() async throws {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.sensor()
        fixture.properties.images[sensor.id] = fixture.image(.purple)
        var release: CheckedContinuation<Void, Never>?
        fixture.properties.beforeImage = { await withCheckedContinuation { release = $0 } }
        await fixture.start([sensor])
        await waitForAppState("background pending") { release != nil }
        fixture.send(.delete(sensor.any))
        let updates = fixture.delegate.updates.count
        release?.resume()
        await flushAppBindings()
        await flushAppBindings()
        XCTAssertNil(fixture.service.getSnapshot(for: sensor.id))
        XCTAssertEqual(fixture.delegate.updates.count, updates)
    }

    func testDuplicateSensorInsertsDoNotCreateDuplicateCardsOrObservers() async {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.sensor()
        await fixture.start([sensor])
        fixture.send(.insert(sensor.any))
        fixture.send(.insert(sensor.any))
        XCTAssertEqual(fixture.service.getAllSnapshots().map(\.id), [sensor.id])
        XCTAssertEqual(fixture.service.getAllSensors().map(\.id), [sensor.id])
        XCTAssertEqual(fixture.reactor.latest.count, 1)
        XCTAssertEqual(fixture.reactor.settings.count, 1)
        XCTAssertTrue(fixture.delegate.inserted.isEmpty)
    }

    func testReactorErrorsAreReportedExceptDuringBulkSyncAndStoppedObserversAreRemoved() async {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.sensor()
        await fixture.start([sensor])
        let error = RuuviReactorError.ruuviPersistence(.failedToFindRuuviTag)
        fixture.send(.error(error))
        fixture.reactor.sendSettings(sensor, .error(error))
        XCTAssertEqual(fixture.delegate.errors.count, 2)
        fixture.measurements.settings.syncExtensiveChangesInProgress = true
        fixture.send(.error(error))
        fixture.reactor.sendSettings(sensor, .error(error))
        XCTAssertEqual(fixture.delegate.errors.count, 2)
        let lists = fixture.delegate.lists.count
        fixture.service.reorderSnapshots(with: [sensor.macId!.value])
        let other = fixture.sensor("Second")
        fixture.send(.insert(other.any))
        fixture.send(.delete(other.any))
        XCTAssertEqual(fixture.delegate.lists.count, lists)
        XCTAssertTrue(fixture.delegate.inserted.isEmpty)
        fixture.service.stopObservingSensors()
        XCTAssertTrue(fixture.reactor.sensors.isEmpty)
        XCTAssertTrue(fixture.reactor.settings.isEmpty)
        XCTAssertTrue(fixture.reactor.latest.isEmpty)
    }
}
