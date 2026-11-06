import Foundation
import RuuviCloud
import RuuviOntology
import XCTest
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviServiceSensorProperties
#endif

@MainActor final class SensorPropertiesSettingsTests: XCTestCase {
    func testDisplaySettingsPersistAndSendJsonOrderWithSeparateTimestamps() async throws {
        let fixture = try PropertiesFixture()
        _ = try await fixture.pool.create(fixture.sensor)
        let before = Date()
        let order = ["temperature", "humidity", "name with \"quotes\""]
        let saved = try await fixture.service.updateDisplaySettings(
            for: fixture.sensor,
            displayOrder: order, defaultDisplayOrder: false)
        XCTAssertEqual(saved.displayOrder, order)
        XCTAssertEqual(saved.defaultDisplayOrder, false)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(saved.displayOrderLastUpdated), before)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(saved.defaultDisplayOrderLastUpdated), before)
        let request = try XCTUnwrap(fixture.cloud.sensorSettingWrites.last)
        XCTAssertEqual(
            request.0,
            [
                RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue,
                RuuviCloudApiSetting.sensorDisplayOrder.rawValue,
            ])
        XCTAssertEqual(request.1[0], "false")
        let decoded = try JSONDecoder().decode([String].self, from: Data(request.1[1].utf8))
        XCTAssertEqual(decoded, order)
        let read = try await fixture.pool.readSensorSettings(fixture.sensor)
        let stored = try XCTUnwrap(read)
        XCTAssertEqual(stored.displayOrder, order)
    }

    func testUnchangedDisplayOrderKeepsItsTimestampWhileDefaultChoiceChanges() async throws {
        let fixture = try PropertiesFixture()
        _ = try await fixture.pool.create(fixture.sensor)
        let old = Date(timeIntervalSince1970: 1_000_000)
        _ = try await fixture.pool.updateDisplaySettings(
            for: fixture.sensor, displayOrder: ["temperature"],
            defaultDisplayOrder: false, displayOrderLastUpdated: old, defaultDisplayOrderLastUpdated: old)
        let saved = try await fixture.service.updateDisplaySettings(
            for: fixture.sensor,
            displayOrder: ["temperature"], defaultDisplayOrder: true)
        XCTAssertEqual(saved.displayOrderLastUpdated, old)
        XCTAssertGreaterThan(try XCTUnwrap(saved.defaultDisplayOrderLastUpdated), old)
        let again = try await fixture.service.updateDisplaySettings(
            for: fixture.sensor,
            displayOrder: ["temperature"], defaultDisplayOrder: true)
        XCTAssertEqual(again.displayOrderLastUpdated, old)
        XCTAssertEqual(again.defaultDisplayOrderLastUpdated, saved.defaultDisplayOrderLastUpdated)
    }

    func testNilAndEmptyOrdersSendOnlyTheDefaultSelectionToCloud() async throws {
        let fixture = try PropertiesFixture()
        _ = try await fixture.pool.create(fixture.sensor)
        for order: [String]? in [nil, []] {
            _ = try await fixture.service.updateDisplaySettings(
                for: fixture.sensor,
                displayOrder: order, defaultDisplayOrder: true)
            XCTAssertEqual(
                fixture.cloud.sensorSettingWrites.last?.0,
                [RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue])
            XCTAssertEqual(fixture.cloud.sensorSettingWrites.last?.1, ["true"])
        }
    }

    func testDescriptionIsPersistedAndClearingItSendsAnEmptyCloudValue() async throws {
        let fixture = try PropertiesFixture()
        _ = try await fixture.pool.create(fixture.sensor)
        let old = Date(timeIntervalSince1970: 1_000_000)
        _ = try await fixture.pool.updateDescription(
            for: fixture.sensor, description: "Existing",
            descriptionLastUpdated: old)
        let same = try await fixture.service.updateDescription(for: fixture.sensor, description: "Existing")
        XCTAssertEqual(same.descriptionLastUpdated, old)
        let changed = try await fixture.service.updateDescription(for: fixture.sensor, description: "Room details")
        XCTAssertEqual(changed.description, "Room details")
        XCTAssertGreaterThan(try XCTUnwrap(changed.descriptionLastUpdated), old)
        let cleared = try await fixture.service.updateDescription(for: fixture.sensor, description: nil)
        XCTAssertNil(cleared.description)
        XCTAssertEqual(fixture.cloud.sensorSettingWrites.map { $0.1 }, [["Existing"], ["Room details"], [""]])
        XCTAssertEqual(fixture.cloud.sensorSettingWrites.last?.0, [RuuviCloudApiSetting.sensorDescription.rawValue])
    }

    func testLocalSensorSettingsStayLocalAndCloudFailuresPreserveLocalEdits() async throws {
        let fixture = try PropertiesFixture()
        var sensor = fixture.sensor
        sensor.isCloudSensor = false
        sensor.isClaimed = false
        _ = try await fixture.pool.create(sensor)
        _ = try await fixture.service.updateDescription(for: sensor, description: "Local description")
        _ = try await fixture.service.updateDisplaySettings(
            for: sensor, displayOrder: ["temperature"], defaultDisplayOrder: false)
        XCTAssertTrue(fixture.cloud.sensorSettingWrites.isEmpty)
        fixture.cloud.sensorSettingsFailure = .notAuthorized
        do {
            _ = try await fixture.service.updateDescription(for: fixture.sensor, description: "Offline edit")
            XCTFail("Offline description upload succeeded")
        } catch {
            guard case .ruuviCloud(.notAuthorized) = error else { return XCTFail("Unexpected \(error)") }
        }
        do {
            _ = try await fixture.service.updateDisplaySettings(
                for: fixture.sensor, displayOrder: ["humidity"], defaultDisplayOrder: true)
            XCTFail("Offline order upload succeeded")
        } catch {
            guard case .ruuviCloud(.notAuthorized) = error else { return XCTFail("Unexpected \(error)") }
        }
        let value = try await fixture.pool.readSensorSettings(sensor)
        XCTAssertEqual(value?.description, "Offline edit")
        XCTAssertEqual(value?.displayOrder, ["humidity"])
    }
}
