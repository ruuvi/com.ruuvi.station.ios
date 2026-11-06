import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class GraphHistoryCommandTests: XCTestCase {
    func testHistoryDownloadStartsWithinRetentionAndOnlySuccessfulCompletionAdvancesItsDate() async throws {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.measurements.sensor
        let settings = fixture.measurements.settings
        settings.dataPruningOffsetHours = 24
        settings.connectionTimeout = 7
        settings.serviceTimeout = 9
        let now = Date()
        for saved in [nil, now.addingTimeInterval(-48 * 3600), now.addingTimeInterval(-3600)] {
            fixture.sync.setGattSyncDate(saved, for: sensor.macId)
            try await fixture.interactor.syncRecords(progress: nil)
            let request = try XCTUnwrap(fixture.gatt.requests.last)
            XCTAssertEqual(request.uuid, sensor.luid?.value)
            XCTAssertEqual(request.mac, sensor.macId?.value)
            XCTAssertEqual(request.firmware, sensor.version)
            XCTAssertEqual(
                request.from.timeIntervalSince1970,
                (saved.map { max($0, now.addingTimeInterval(-24 * 3600)) } ?? now.addingTimeInterval(-24 * 3600))
                    .timeIntervalSince1970,
                accuracy: 2)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(fixture.sync.getGattSyncDate(for: sensor.macId)), now)
        }
        fixture.sync.setGattSyncDate(now, for: sensor.macId)
        fixture.gatt.result = false
        try await fixture.interactor.syncRecords(progress: nil)
        XCTAssertEqual(fixture.sync.getGattSyncDate(for: sensor.macId), now)
        fixture.gatt.failure = .failedToParseNetworkResponse
        do { try await fixture.interactor.syncRecords(progress: nil); XCTFail("Failed transfer succeeded") } catch {
            guard case .ruuviService(.failedToParseNetworkResponse) = error else {
                return XCTFail("Unexpected \(error)")
            }
        }
        XCTAssertEqual(fixture.sync.getGattSyncDate(for: sensor.macId), now)
    }

    func testCloudOnlySensorsRejectBluetoothCommandsWithoutStartingRadioWork() async {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        var sensor = fixture.measurements.sensor
        sensor.luid = nil
        fixture.interactor.ruuviTagSensor = sensor.any
        do {
            try await fixture.interactor.syncRecords(progress: nil); XCTFail("Missing local identity succeeded")
        } catch {
            guard case .unexpected(.callbackErrorAndResultAreNil) = error else { return XCTFail("Unexpected \(error)") }
        }
        do {
            _ = try await fixture.interactor.stopSyncRecords(); XCTFail("Missing local identity stopped a transfer")
        } catch {
            guard case .unexpected(.callbackErrorAndResultAreNil) = error else { return XCTFail("Unexpected \(error)") }
        }
        XCTAssertTrue(fixture.gatt.requests.isEmpty)
        XCTAssertTrue(fixture.gatt.stops.isEmpty)
    }

    func testDeletionStopsTheSensorDownloadBeforeClearingAndKeepsSuccessfulAirSuppression() async throws {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.measurements.sensor
        fixture.records.beforeClear = { XCTAssertEqual(fixture.gatt.stops, [sensor.luid!.value]) }
        defer { fixture.records.beforeClear = nil }
        try await fixture.interactor.deleteAllRecords(for: sensor)
        XCTAssertEqual(fixture.records.cleared, [sensor.id])
        XCTAssertTrue(fixture.sync.isAutoGattSyncSuppressed(for: sensor.macId))
        await waitForAppState("history reloaded after deletion") { fixture.output.loaded == 1 }
    }

    func testFailedDeletionRestoresPreviousSyncEligibilityAndDoesNotClearAfterFailedCancellation() async {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.measurements.sensor
        fixture.gatt.stopFailure = .failedToParseNetworkResponse
        do { try await fixture.interactor.deleteAllRecords(for: sensor); XCTFail("Cancellation failure ignored") } catch
        {
            guard case .ruuviService(.failedToParseNetworkResponse) = error else {
                return XCTFail("Unexpected \(error)")
            }
        }
        XCTAssertTrue(fixture.records.cleared.isEmpty)
        XCTAssertFalse(fixture.sync.isAutoGattSyncSuppressed(for: sensor.macId))
        fixture.gatt.stopFailure = nil
        fixture.records.failure = .failedToParseNetworkResponse
        fixture.sync.setAutoGattSyncSuppressed(true, for: sensor.macId)
        do { try await fixture.interactor.deleteAllRecords(for: sensor); XCTFail("Deletion failure ignored") } catch {
            guard case .ruuviService(.failedToParseNetworkResponse) = error else {
                return XCTFail("Unexpected \(error)")
            }
        }
        XCTAssertTrue(fixture.sync.isAutoGattSyncSuppressed(for: sensor.macId))
        XCTAssertEqual(fixture.output.loaded, 0)
    }

    func testExportAndAutomaticSyncStateStayScopedToTheConfiguredSensor() async throws {
        let fixture = GraphHistoryFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.measurements.sensor
        let date = Date()
        fixture.interactor.setAutoGattSyncAttemptDate(date)
        XCTAssertEqual(fixture.interactor.getAutoGattSyncAttemptDate(), date)
        fixture.sync.setGattSyncDate(date, for: sensor.macId)
        XCTAssertEqual(fixture.interactor.getLastGattSyncDate(), date)
        fixture.interactor.setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(true)
        XCTAssertTrue(fixture.interactor.hasLoggedFirstAutoSyncGattHistoryForRuuviAir())
        fixture.sync.setAutoGattSyncSuppressed(true, for: sensor.macId)
        XCTAssertTrue(fixture.interactor.isAutoGattSyncSuppressed())
        let url = try await fixture.interactor.export()
        XCTAssertEqual(url, fixture.export.url)
        XCTAssertEqual(fixture.export.requests.first?.id, sensor.id)
        fixture.export.failure = .failedToParseNetworkResponse
        do { _ = try await fixture.interactor.export(); XCTFail("Failed export succeeded") } catch {
            guard case .ruuviService(.failedToParseNetworkResponse) = error else {
                return XCTFail("Unexpected \(error)")
            }
        }
        _ = try await fixture.interactor.stopSyncRecords()
        XCTAssertEqual(fixture.gatt.stops, [sensor.luid!.value])
        fixture.interactor.ruuviTagSensor = nil
        fixture.interactor.setAutoGattSyncAttemptDate(nil)
        XCTAssertNil(fixture.interactor.getAutoGattSyncAttemptDate())
        XCTAssertNil(fixture.interactor.getLastGattSyncDate())
        XCTAssertFalse(fixture.interactor.isAutoGattSyncSuppressed())
    }
}
