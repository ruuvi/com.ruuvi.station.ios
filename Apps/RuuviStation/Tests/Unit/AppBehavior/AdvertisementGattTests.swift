import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class AdvertisementGattTests: XCTestCase {
    func testLiveAirPacketsStartHistorySyncWithConfiguredWindowAndTimeoutsAndThenRespectCooldown() async throws {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        fixture.measurements.flags.autoSyncGattHistoryForRuuviAir = true
        fixture.measurements.flags.autoSyncGattHistoryForRuuviAirMinimumLastSyncDateAgeMinutes = 10
        fixture.measurements.settings.dataPruningOffsetHours = 24
        fixture.measurements.settings.connectionTimeout = 12
        fixture.measurements.settings.serviceTimeout = 13
        let before = Date()
        await fixture.start()
        fixture.emit(try fixture.airPacket())
        await waitForAppState("automatic history finished") {
            fixture.sync.getGattSyncDate(for: fixture.sensor.macId) != nil
        }
        let request = try XCTUnwrap(fixture.gatt.requests.first)
        XCTAssertEqual(request.uuid, fixture.sensor.luid?.value)
        XCTAssertEqual(request.mac, fixture.sensor.macId?.value)
        XCTAssertEqual(request.firmware, 6)
        XCTAssertEqual(request.timeouts.connection, 12)
        XCTAssertEqual(request.timeouts.service, 13)
        XCTAssertGreaterThanOrEqual(request.from, before.addingTimeInterval(-24 * 3600))
        XCTAssertLessThanOrEqual(request.from, Date())
        XCTAssertTrue(fixture.sync.hasLoggedFirstAutoSyncGattHistoryForRuuviAir(for: fixture.sensor.macId))
        XCTAssertNotNil(fixture.sync.getAutoGattSyncAttemptDate(for: fixture.sensor.macId))
        fixture.emit(try fixture.airPacket(sequence: 2))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.gatt.requests.count, 1)
    }

    func testAnotherSensorsSyncBlocksAutomaticHistoryUnlessConcurrencyIsEnabled() async throws {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        fixture.measurements.flags.autoSyncGattHistoryForRuuviAir = true
        fixture.gatt.globallySyncing = true
        await fixture.start()
        fixture.emit(try fixture.airPacket())
        await waitForAppState("advertisement received during another sync") { fixture.pool.createdLatest.count == 1 }
        XCTAssertTrue(fixture.gatt.requests.isEmpty)
        fixture.measurements.flags.allowConcurrentGattSyncForMultipleSensors = true
        fixture.emit(try fixture.airPacket(sequence: 2))
        await waitForAppState("concurrent automatic sync") { fixture.gatt.requests.count == 1 }
    }

    func testDisabledBackgroundCloudSuppressedAndAlreadySyncingSensorsDoNotStartDownloads() async throws {
        for condition in 0..<6 {
            let fixture = AdvertisementFixture()
            defer { fixture.cleanup() }
            fixture.measurements.flags.autoSyncGattHistoryForRuuviAir = condition != 0
            if condition == 1 { fixture.measurements.settings.appIsOnForeground = false }
            if condition == 2 { fixture.sensor.isCloudSensor = true }
            if condition == 3 { fixture.sync.setAutoGattSyncSuppressed(true, for: fixture.sensor.macId) }
            if condition == 4 { fixture.gatt.syncingIDs.insert(fixture.sensor.luid!.value) }
            if condition == 5 { fixture.sensor.macId = nil }
            await fixture.start()
            fixture.emit(try fixture.airPacket())
            await waitForAppState("advertisement persisted without automatic sync") {
                fixture.pool.createdLatest.count == 1
            }
            XCTAssertTrue(fixture.gatt.requests.isEmpty, "Condition \(condition)")
        }
    }

    func testFailedOrIncompleteHistoryDoesNotAdvanceSuccessfulSyncDate() async throws {
        for fails in [true, false] {
            let fixture = AdvertisementFixture()
            defer { fixture.cleanup() }
            fixture.measurements.flags.autoSyncGattHistoryForRuuviAir = true
            fixture.gatt.failure = fails ? .failedToParseNetworkResponse : nil
            fixture.gatt.result = false
            await fixture.start()
            fixture.emit(try fixture.airPacket())
            await waitForAppState("attempted history") { fixture.gatt.requests.count == 1 }
            await flushAppBindings()
            XCTAssertNil(fixture.sync.getGattSyncDate(for: fixture.sensor.macId))
            XCTAssertNotNil(fixture.sync.getAutoGattSyncAttemptDate(for: fixture.sensor.macId))
        }
    }
}
