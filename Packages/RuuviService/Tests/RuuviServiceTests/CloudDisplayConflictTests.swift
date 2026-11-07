import Foundation
import RuuviCloud
import RuuviOntology
import XCTest
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviServiceCloudSync
#endif

@MainActor final class CloudDisplayConflictTests: XCTestCase {
    func testNewerLocalDisplaySettingsAndDeletedNotesAreUploadedWithoutRestoringOldCloudValues() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        let localDate = fixture.date.addingTimeInterval(60)
        _ = try await fixture.pool.updateDisplaySettings(
            for: fixture.sensor, displayOrder: ["co2", "temperature"],
            defaultDisplayOrder: false, displayOrderLastUpdated: localDate, defaultDisplayOrderLastUpdated: localDate)
        _ = try await fixture.pool.updateDescription(
            for: fixture.sensor, description: nil, descriptionLastUpdated: localDate)
        let cloud = RuuviCloudSensorSettings(
            displayOrderCodes: ["temperature"], defaultDisplayOrder: true,
            displayOrderLastUpdated: fixture.date, defaultDisplayOrderLastUpdated: fixture.date,
            description: "Deleted note", descriptionLastUpdated: fixture.date)
        fixture.cloud.onDense = { [fixture.dense(display: cloud)] }
        _ = try await fixture.service.refreshLatestRecord()
        let request = try XCTUnwrap(fixture.cloud.sensorSettingWrites.last)
        let payload = Dictionary(uniqueKeysWithValues: zip(request.0, request.1))
        XCTAssertEqual(payload[RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue], "false")
        let order = try XCTUnwrap(payload[RuuviCloudApiSetting.sensorDisplayOrder.rawValue]?.data(using: .utf8))
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: order), ["co2", "temperature"])
        XCTAssertEqual(payload[RuuviCloudApiSetting.sensorDescription.rawValue], "")
        let stored = try await fixture.storage.readSensorSettings(fixture.sensor)
        XCTAssertEqual(stored?.displayOrder, ["co2", "temperature"])
        XCTAssertEqual(stored?.defaultDisplayOrder, false)
        XCTAssertNil(stored?.description)
        XCTAssertEqual(stored?.descriptionLastUpdated, localDate)
    }

    func testMixedTimestampWinnersReconcileEachSettingIndependentlyEvenWhenUploadFails() async throws {
        let fixture = try CloudSyncFixture()
        defer { fixture.close() }
        try await fixture.pool.create(fixture.sensor)
        let newer = fixture.date.addingTimeInterval(60)
        _ = try await fixture.pool.updateDisplaySettings(
            for: fixture.sensor, displayOrder: ["co2"],
            defaultDisplayOrder: true, displayOrderLastUpdated: fixture.date, defaultDisplayOrderLastUpdated: newer)
        _ = try await fixture.pool.updateDescription(
            for: fixture.sensor, description: "New local note", descriptionLastUpdated: newer)
        let cloud = RuuviCloudSensorSettings(
            displayOrderCodes: ["humidity", "temperature"], defaultDisplayOrder: false,
            displayOrderLastUpdated: newer, defaultDisplayOrderLastUpdated: fixture.date,
            description: "Old cloud note", descriptionLastUpdated: fixture.date)
        fixture.cloud.sensorSettingsFailure = .notAuthorized
        fixture.cloud.onDense = { [fixture.dense(display: cloud)] }
        _ = try await fixture.service.refreshLatestRecord()
        let request = try XCTUnwrap(fixture.cloud.sensorSettingWrites.last)
        let payload = Dictionary(uniqueKeysWithValues: zip(request.0, request.1))
        XCTAssertNil(payload[RuuviCloudApiSetting.sensorDisplayOrder.rawValue])
        XCTAssertEqual(payload[RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue], "true")
        XCTAssertEqual(payload[RuuviCloudApiSetting.sensorDescription.rawValue], "New local note")
        let stored = try await fixture.storage.readSensorSettings(fixture.sensor)
        XCTAssertEqual(stored?.displayOrder, ["humidity", "temperature"])
        XCTAssertEqual(stored?.defaultDisplayOrder, true)
        XCTAssertEqual(stored?.description, "New local note")
        XCTAssertEqual(stored?.displayOrderLastUpdated, newer)
        XCTAssertEqual(stored?.descriptionLastUpdated, newer)
    }
}
