import Foundation
import XCTest
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviService
#if SWIFT_PACKAGE
    import RuuviServiceCloudSync
#endif

@MainActor final class CloudSensorSyncTests: XCTestCase {
    func testRefreshCreatesSensorHistoryOffsetsAndDisplaySettings() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        var cloud = fixture.cloudSensor()
        cloud.offsetTemperature = 1.5
        cloud.offsetHumidity = 5
        cloud.offsetPressure = 150
        let display = RuuviCloudSensorSettings(
            displayOrderCodes: ["temperature", "humidity"], defaultDisplayOrder: false,
            displayOrderLastUpdated: fixture.date, defaultDisplayOrderLastUpdated: fixture.date,
            description: "Greenhouse", descriptionLastUpdated: fixture.date)
        fixture.cloud.onDense = { [fixture.dense(cloud, record: fixture.record(), display: display)] }
        let refreshed = try await fixture.service.refreshLatestRecord()
        XCTAssertTrue(refreshed)
        let stored = try await fixture.storage.readOne(fixture.sensor.id)
        XCTAssertEqual(stored.name, "Cloud sensor")
        let settings = try await fixture.storage.readSensorSettings(stored)
        XCTAssertEqual(settings?.temperatureOffset, 1.5)
        XCTAssertEqual(settings?.humidityOffset, 0.05)
        XCTAssertEqual(settings?.pressureOffset, 1.5)
        XCTAssertEqual(settings?.displayOrder, display.displayOrderCodes)
        XCTAssertEqual(settings?.defaultDisplayOrder, false)
        XCTAssertEqual(settings?.description, "Greenhouse")
        let latest = try await fixture.storage.readLatest(stored)
        let history = try await fixture.storage.readAll(stored.id)
        XCTAssertEqual(latest?.date, fixture.date)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(fixture.syncState.getSyncStatusLatestRecord(for: stored.macId!), .complete)
    }

    func testOlderCloudMeasurementCannotReplaceNewerBluetoothMeasurement() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        try await fixture.pool.createLast(fixture.record(seconds: 60))
        try await fixture.pool.create(fixture.record(seconds: 60))
        fixture.cloud.onDense = { [fixture.dense(record: fixture.record())] }
        _ = try await fixture.service.refreshLatestRecord()
        var latest = try await fixture.storage.readLatest(fixture.sensor)
        var records = try await fixture.storage.readAll(fixture.sensor.id)
        XCTAssertEqual(latest?.date, fixture.date.addingTimeInterval(60))
        XCTAssertEqual(records.count, 1)
        fixture.cloud.onDense = { [fixture.dense(record: fixture.record(seconds: 120))] }
        _ = try await fixture.service.refreshLatestRecord()
        latest = try await fixture.storage.readLatest(fixture.sensor)
        records = try await fixture.storage.readAll(fixture.sensor.id)
        XCTAssertEqual(latest?.date, fixture.date.addingTimeInterval(120))
        XCTAssertEqual(records.count, 2)
    }

    func testCloudModeCanReplaceLatestRecordWithCloudSnapshot() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        try await fixture.pool.createLast(fixture.record(seconds: 60))
        fixture.settings.cloudModeEnabled = true
        fixture.cloud.onDense = { [fixture.dense(record: fixture.record())] }
        _ = try await fixture.service.refreshLatestRecord()
        let latest = try await fixture.storage.readLatest(fixture.sensor)
        XCTAssertEqual(latest?.date, fixture.date)
    }

    func testNewerLocalNameSurvivesCloudSnapshotWhileSubscriptionRefreshes() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        fixture.sensor.lastUpdated = fixture.date
        try await fixture.pool.create(fixture.sensor)
        let cloud = fixture.cloudSensor(updated: fixture.date.addingTimeInterval(-100), days: 365, plan: "Pro")
        var queuedName: String?
        fixture.cloud.onName = { queuedName = $0 }
        fixture.cloud.onDense = { [fixture.dense(cloud)] }
        _ = try await fixture.service.refreshLatestRecord()
        let stored = try await fixture.storage.readOne(fixture.sensor.id)
        XCTAssertEqual(stored.name, "Local sensor")
        XCTAssertEqual(queuedName, "Local sensor")
        XCTAssertEqual(stored.ownersPlan, "Pro")
        XCTAssertEqual(stored.maxHistoryDays, 365)
        XCTAssertEqual(fixture.syncState.downloadFullHistory(for: fixture.sensor.macId), true)
    }

    func testNewerCloudNameWinsAndSubscriptionRemovalClearsFullHistoryFlag() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        fixture.sensor.lastUpdated = fixture.date.addingTimeInterval(-100)
        try await fixture.pool.create(fixture.sensor)
        fixture.syncState.setDownloadFullHistory(for: fixture.sensor.macId, downloadFull: true)
        let cloud = fixture.cloudSensor(updated: fixture.date, days: 0)
        fixture.cloud.onDense = { [fixture.dense(cloud)] }
        _ = try await fixture.service.refreshLatestRecord()
        let stored = try await fixture.storage.readOne(fixture.sensor.id)
        XCTAssertEqual(stored.name, "Cloud sensor")
        XCTAssertEqual(stored.maxHistoryDays, 0)
        XCTAssertNil(fixture.syncState.downloadFullHistory(for: fixture.sensor.macId))
    }

    func testCloudRemovalDeletesCloudSensorWithoutTryingToUpdateDeletedRow() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        fixture.syncState.setDownloadFullHistory(for: fixture.sensor.macId, downloadFull: true)
        let result = try await fixture.service.refreshLatestRecord()
        XCTAssertTrue(result)
        let remaining = try await fixture.storage.readAll()
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertEqual(fixture.syncState.getSyncStatusLatestRecord(for: fixture.sensor.macId!), .none)
        XCTAssertNil(fixture.syncState.downloadFullHistory(for: fixture.sensor.macId))
    }

    func testForeignLocallyDiscoveredSensorKeepsOwnerWhenMissingFromCloud() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        fixture.sensor.isCloudSensor = false
        fixture.sensor.isOwner = false
        fixture.sensor.isClaimed = false
        fixture.sensor.owner = "someone@example.com"
        try await fixture.pool.create(fixture.sensor)
        _ = try await fixture.service.refreshLatestRecord()
        let stored = try await fixture.storage.readOne(fixture.sensor.id)
        XCTAssertEqual(stored.owner, "someone@example.com")
    }

    func testSyncFailureAlwaysRestoresBusyFlagsAndReportsAuthorizationFailure() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        fixture.cloud.onDense = { () throws(RuuviCloudError) in throw .api(.api(.erUnauthorized)) }
        let unauthorized = expectation(forNotification: .NetworkSyncDidFailForAuthorization, object: nil)
        do {
            _ = try await fixture.service.syncAllRecords()
            XCTFail("Expected unauthorized failure")
        } catch {
            guard case .ruuviCloud(.api(.api(.erUnauthorized))) = error else { return XCTFail("Unexpected \(error)") }
        }
        await fulfillment(of: [unauthorized], timeout: 3)
        XCTAssertFalse(fixture.settings.isSyncing)
        XCTAssertEqual(fixture.syncState.getSyncStatusLatestRecord(for: fixture.sensor.macId!), .onError)
    }

    func testMissingCloudSettingsAndMissingPictureAreExplicitErrors() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        fixture.cloud.onSettings = { nil }
        do {
            _ = try await fixture.service.syncSettings()
            XCTFail("Expected empty response")
        } catch { guard case .ruuviCloud(.api(.emptyResponse)) = error else { return XCTFail("Unexpected \(error)") } }
        do {
            _ = try await fixture.service.syncImage(sensor: fixture.cloudSensor())
            XCTFail("Expected missing picture")
        } catch { guard case .pictureUrlIsNil = error else { return XCTFail("Unexpected \(error)") } }
    }
}
