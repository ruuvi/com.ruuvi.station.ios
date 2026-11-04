import Foundation
import XCTest
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviService
#if SWIFT_PACKAGE
    import RuuviServiceCloudSync
#endif

@MainActor final class CloudHistorySyncTests: XCTestCase {
    func testHistoryIsSavedBeforeReturnAndCursorUsesNewestRecord() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        let records = [fixture.record(seconds: 120), fixture.record(seconds: 0), fixture.record(seconds: 60)]
        let previous = fixture.date.addingTimeInterval(-60)
        fixture.syncState.setSyncDate(previous, for: fixture.sensor.macId)
        fixture.cloud.onHistory = { mac, since in
            XCTAssertEqual(mac.value, fixture.sensor.macId?.value)
            XCTAssertEqual(since, previous)
            return records.map(\.any)
        }
        let received = try await fixture.service.sync(sensor: fixture.sensor)
        XCTAssertEqual(received.count, 3)
        XCTAssertTrue(received.allSatisfy { $0.luid?.value == fixture.sensor.luid?.value })
        let stored = try await fixture.storage.readAll(fixture.sensor.id)
        XCTAssertEqual(stored.map(\.date), records.map(\.date).sorted())
        XCTAssertEqual(fixture.syncState.getSyncDate(for: fixture.sensor.macId), fixture.date.addingTimeInterval(120))
        XCTAssertEqual(fixture.syncState.downloadFullHistory(for: fixture.sensor.macId), false)
    }

    func testSameSensorHistoryRequestsCoalesceWhileAnotherRequestIsInFlight() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        let started = expectation(description: "History request started")
        let gate = AsyncStream<Void>.makeStream()
        defer { gate.continuation.finish() }
        var calls = 0
        fixture.cloud.onHistory = { _, _ in
            calls += 1
            started.fulfill()
            for await _ in gate.stream { break }
            return [fixture.record().any]
        }
        let first = Task { try await fixture.service.sync(sensor: fixture.sensor) }
        await fulfillment(of: [started], timeout: 3)
        let concurrent = try await fixture.service.sync(sensor: fixture.sensor)
        XCTAssertTrue(concurrent.isEmpty)
        XCTAssertEqual(calls, 1)
        gate.continuation.finish()
        let result = try await first.value
        XCTAssertEqual(result.count, 1)
    }

    func testFailedHistoryReleasesInFlightStateAndKeepsCursorForRetry() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        fixture.syncState.setSyncDate(fixture.date, for: fixture.sensor.macId)
        fixture.syncState.setDownloadFullHistory(for: fixture.sensor.macId, downloadFull: true)
        fixture.cloud.onHistory = { _, _ throws(RuuviCloudError) in throw .notAuthorized }
        do {
            _ = try await fixture.service.sync(sensor: fixture.sensor)
            XCTFail("Expected cloud failure")
        } catch { guard case .ruuviCloud(.notAuthorized) = error else { return XCTFail("Unexpected \(error)") } }
        XCTAssertEqual(fixture.syncState.getSyncDate(for: fixture.sensor.macId), fixture.date)
        XCTAssertEqual(fixture.syncState.downloadFullHistory(for: fixture.sensor.macId), true)
        fixture.cloud.onHistory = { _, since in
            XCTAssertLessThan(since, fixture.date)
            return [fixture.record(seconds: 60).any]
        }
        let retried = try await fixture.service.sync(sensor: fixture.sensor)
        XCTAssertEqual(retried.count, 1)
        XCTAssertEqual(fixture.syncState.getSyncDate(for: fixture.sensor.macId), fixture.date.addingTimeInterval(60))
    }

    func testHistoryEligibilityAndMissingMacAreExplicit() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        var calls = 0
        fixture.cloud.onHistory = { _, _ in
            calls += 1; return []
        }
        fixture.sensor.maxHistoryDays = nil
        let noPlan = try await fixture.service.sync(sensor: fixture.sensor)
        XCTAssertTrue(noPlan.isEmpty)
        fixture.sensor.maxHistoryDays = 0
        let noHistory = try await fixture.service.sync(sensor: fixture.sensor)
        XCTAssertTrue(noHistory.isEmpty)
        fixture.sensor.maxHistoryDays = 10
        var missingMAC = fixture.sensor
        missingMAC.macId = nil
        do {
            _ = try await fixture.service.sync(sensor: missingMAC)
            XCTFail("Missing MAC must fail explicitly")
        } catch { guard case .macIdIsNil = error else { return XCTFail("Unexpected \(error)") } }
        XCTAssertEqual(calls, 0)
    }

    func testAllHistoryOnlyLoadsCloudSensorsWithHistoryAndLatestData() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        var calls = 0
        fixture.cloud.onHistory = { _, _ in
            calls += 1; return []
        }
        _ = try await fixture.service.syncAllHistory()
        XCTAssertEqual(calls, 0)
        try await fixture.pool.createLast(fixture.record())
        _ = try await fixture.service.syncAllHistory()
        XCTAssertEqual(calls, 1)
        fixture.sensor.maxHistoryDays = 0
        try await fixture.pool.update(fixture.sensor)
        _ = try await fixture.service.syncAllHistory()
        XCTAssertEqual(calls, 1)
    }
}
