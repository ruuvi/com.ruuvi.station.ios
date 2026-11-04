import Foundation
import XCTest
import RuuviOntology
import RuuviService
import RuuviStorage
@testable import RuuviMigration
#if SWIFT_PACKAGE
    @testable import RuuviMigrationImpl
#endif

@MainActor final class VisibilityMigrationTests: XCTestCase {
    func testOwnedSensorWithSignalAlertPreservesCustomOrderAndCalibration() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let sensor = try await fixture.sensor()
        fixture.alerts.register(type: .signal(lower: -100, upper: -50), ruuviTag: sensor)
        _ = try await fixture.persistence.updateOffsetCorrection(
            type: .temperature, with: 2, of: sensor, lastOriginalRecord: nil)
        _ = try await fixture.properties.updateDisplaySettings(
            for: sensor, displayOrder: ["HUMIDITY_0", "TEMPERATURE_F"], defaultDisplayOrder: true)
        fixture.properties.writes.removeAll()
        try await fixture.visibilityMigration.migrate()
        let settings = try await fixture.storage.readSensorSettings(sensor)
        XCTAssertEqual(settings?.displayOrder, ["HUMIDITY_0", "TEMPERATURE_F", "SIGNAL_DBM"])
        XCTAssertEqual(settings?.defaultDisplayOrder, false)
        XCTAssertEqual(settings?.temperatureOffset, 2)
        XCTAssertEqual(fixture.properties.writes.count, 1)
        XCTAssertTrue(fixture.defaults.bool(forKey: "MigrationManagerSignalVisibility.didMigrate"))
        XCTAssertFalse(fixture.settings.signalVisibilityMigrationInProgress)
        fixture.settings.signalVisibilityMigrationInProgress = true
        try await fixture.visibilityMigration.migrate()
        XCTAssertEqual(fixture.properties.writes.count, 1)
        XCTAssertFalse(fixture.settings.signalVisibilityMigrationInProgress)
    }

    func testDefaultOrdersForTagAndAirAddSignalOnce() async throws {
        for version in [5, 6, 225] {
            let fixture = try MigrationFixture()
            defer { fixture.close() }
            let sensor = try await fixture.sensor(version: version)
            fixture.alerts.register(type: .signal(lower: -100, upper: -50), ruuviTag: sensor)
            try await fixture.visibilityMigration.migrate()
            let settings = try await fixture.storage.readSensorSettings(sensor)
            let tag = ["TEMPERATURE_C", "HUMIDITY_0", "PRESSURE_1", "MOVEMENT_COUNT", "SIGNAL_DBM"]
            let air = [
                "AQI_INDEX", "CO2_PPM", "PM25_MGM3", "VOC_INDEX", "NOX_INDEX", "TEMPERATURE_C", "HUMIDITY_0",
                "PRESSURE_1", "LUMINOSITY_LX", "SOUNDINSTANT_SPL", "SIGNAL_DBM",
            ]
            XCTAssertEqual(settings?.displayOrder, version == 5 ? tag : air, "Format \(version)")
            fixture.defaults.removeObject(forKey: "MigrationManagerSignalVisibility.didMigrate")
            try await fixture.visibilityMigration.migrate()
            XCTAssertEqual(fixture.properties.writes.count, 1, "Existing signal must not be duplicated")
        }
    }

    func testForeignSensorAndSensorWithoutAlertAreUnchanged() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let foreign = try await fixture.sensor(owner: false)
        _ = try await fixture.sensor()
        fixture.alerts.register(type: .signal(lower: -100, upper: -50), ruuviTag: foreign)
        try await fixture.visibilityMigration.migrate()
        XCTAssertTrue(fixture.properties.writes.isEmpty)
        XCTAssertTrue(fixture.defaults.bool(forKey: "MigrationManagerSignalVisibility.didMigrate"))
    }

    func testFailedWriteRemainsRetryableAndStaleInProgressFlagRecovers() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let sensor = try await fixture.sensor()
        fixture.alerts.register(type: .signal(lower: -100, upper: -50), ruuviTag: sensor)
        fixture.settings.signalVisibilityMigrationInProgress = true
        fixture.properties.failWrite = true
        do {
            try await fixture.visibilityMigration.migrate(); XCTFail("Write failure must propagate")
        } catch is RuuviServiceError {}
        XCTAssertFalse(fixture.defaults.bool(forKey: "MigrationManagerSignalVisibility.didMigrate"))
        XCTAssertFalse(fixture.settings.signalVisibilityMigrationInProgress)
        fixture.properties.failWrite = false
        try await fixture.visibilityMigration.migrate()
        XCTAssertEqual(fixture.properties.writes.count, 1)
        XCTAssertTrue(fixture.defaults.bool(forKey: "MigrationManagerSignalVisibility.didMigrate"))
    }

    func testSettingsReadFailureDoesNotOverwriteCustomOrderWithDefaults() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let sensor = try await fixture.sensor()
        fixture.alerts.register(type: .signal(lower: -100, upper: -50), ruuviTag: sensor)
        _ = try await fixture.properties.updateDisplaySettings(
            for: sensor, displayOrder: ["TEMPERATURE_F"], defaultDisplayOrder: false)
        fixture.properties.writes.removeAll()
        fixture.storage.failSettings = true
        do {
            try await fixture.visibilityMigration.migrate(); XCTFail("Read failure must propagate")
        } catch is RuuviStorageError {}
        XCTAssertTrue(fixture.properties.writes.isEmpty)
        XCTAssertFalse(fixture.defaults.bool(forKey: "MigrationManagerSignalVisibility.didMigrate"))
        fixture.storage.failSettings = false
        try await fixture.visibilityMigration.migrate()
        XCTAssertEqual(fixture.properties.writes.first?.1, ["TEMPERATURE_F", "SIGNAL_DBM"])
    }

    func testEmptyDatabaseDefersMigrationAndReadFailureClearsBusyFlag() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        try await fixture.visibilityMigration.migrate()
        XCTAssertFalse(fixture.defaults.bool(forKey: "MigrationManagerSignalVisibility.didMigrate"))
        fixture.storage.failReadAll = true
        do { try await fixture.visibilityMigration.migrate(); XCTFail("Expected failure") } catch is RuuviStorageError {
        }
        XCTAssertFalse(fixture.settings.signalVisibilityMigrationInProgress)
    }
}
