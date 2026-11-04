import Foundation
import XCTest
import RuuviOntology
import RuuviService
import RuuviStorage
@testable import RuuviMigration
#if SWIFT_PACKAGE
    @testable import RuuviMigrationImpl
#endif

@MainActor final class HumidityMigrationTests: XCTestCase {
    func testLegacyRelativeAlertsAndDescriptionsReachCurrentFormatInOrder() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let sensor = try await fixture.sensor()
        fixture.enableLegacy("relative", sensor: sensor, lower: 25, upper: 75)
        fixture.enableLegacy("absolute", sensor: sensor, lower: 3, upper: 12)
        fixture.defaults.set(
            "Relative description", forKey: fixture.legacy("relative", "AlertDescription", sensor: sensor))
        fixture.defaults.set(
            "Absolute description", forKey: fixture.legacy("absolute", "AlertDescription", sensor: sensor))
        try await RuuviMigrationRunner.migrate([
            fixture.alertMigration, fixture.humidityMigration, fixture.boundsMigration,
        ])
        XCTAssertEqual(try XCTUnwrap(fixture.alerts.lowerRelativeHumidity(for: sensor)), 0.25, accuracy: 0.00001)
        XCTAssertEqual(try XCTUnwrap(fixture.alerts.upperRelativeHumidity(for: sensor)), 0.75, accuracy: 0.00001)
        XCTAssertTrue(fixture.alerts.isOn(type: .relativeHumidity(lower: 0, upper: 1), for: sensor))
        XCTAssertEqual(fixture.alerts.relativeHumidityDescription(for: sensor), "Relative description")
        XCTAssertFalse(fixture.defaults.bool(forKey: fixture.legacy("relative", "AlertIsOn", sensor: sensor)))
        XCTAssertEqual(fixture.defaults.integer(forKey: "MigrationManagerAlertService.persistanceVersion"), 1)
        XCTAssertTrue(fixture.defaults.bool(forKey: "MigrationManagerToRH.migrated"))
        fixture.alerts.setLower(relativeHumidity: 0.3, ruuviTag: sensor)
        try await RuuviMigrationRunner.migrate([
            fixture.alertMigration, fixture.humidityMigration, fixture.boundsMigration,
        ])
        XCTAssertEqual(
            fixture.alerts.lowerRelativeHumidity(for: sensor), 0.3, "Relaunch must preserve later user edits")
    }

    func testLatestRecordCacheAndHistoricalFallbackBothPreserveLegacyAlerts() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let cached = try await fixture.sensor(record: false)
        try await fixture.addRecord(cached, latest: true)
        let historical = try await fixture.sensor()
        for sensor in [cached, historical] {
            fixture.enableLegacy("relative", sensor: sensor, lower: 10, upper: 90)
        }
        try await RuuviMigrationRunner.migrate([fixture.alertMigration, fixture.humidityMigration])
        for sensor in [cached, historical] {
            XCTAssertEqual(try XCTUnwrap(fixture.alerts.lowerRelativeHumidity(for: sensor)), 0.1, accuracy: 0.00001)
            XCTAssertEqual(try XCTUnwrap(fixture.alerts.upperRelativeHumidity(for: sensor)), 0.9, accuracy: 0.00001)
        }
    }

    func testOneMissingRecordDoesNotPartiallyConsumeOtherLegacyAlerts() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let ready = try await fixture.sensor()
        let missing = try await fixture.sensor(record: false)
        for sensor in [ready, missing] { fixture.enableLegacy("relative", sensor: sensor, lower: 10, upper: 90) }
        do {
            try await fixture.alertMigration.migrate(); XCTFail("Expected deferred migration")
        } catch HumidityMigrationError.missingTemperature {}
        for sensor in [ready, missing] {
            XCTAssertTrue(fixture.defaults.bool(forKey: fixture.legacy("relative", "AlertIsOn", sensor: sensor)))
            XCTAssertNil(fixture.alerts.lowerHumidity(for: sensor))
        }
        try await fixture.addRecord(missing)
        try await fixture.alertMigration.migrate()
        for sensor in [ready, missing] { XCTAssertNotNil(fixture.alerts.lowerHumidity(for: sensor)) }
    }

    func testAbsoluteAlertsConvertUsingLatestTemperatureAndKeepDescription() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let sensor = try await fixture.sensor()
        fixture.enableLegacy("absolute", sensor: sensor, lower: 3, upper: 12)
        fixture.defaults.set("Dry room", forKey: fixture.legacy("absolute", "AlertDescription", sensor: sensor))
        try await RuuviMigrationRunner.migrate([fixture.alertMigration, fixture.humidityMigration])
        let temperature = Temperature(value: 20, unit: .celsius)
        let expectedLower = Humidity(value: 3, unit: .absolute).converted(to: .relative(temperature: temperature)).value
        let expectedUpper = Humidity(value: 12, unit: .absolute).converted(to: .relative(temperature: temperature))
            .value
        XCTAssertEqual(
            try XCTUnwrap(fixture.alerts.lowerRelativeHumidity(for: sensor)), expectedLower, accuracy: 0.00001)
        XCTAssertEqual(
            try XCTUnwrap(fixture.alerts.upperRelativeHumidity(for: sensor)), expectedUpper, accuracy: 0.00001)
        XCTAssertEqual(fixture.alerts.relativeHumidityDescription(for: sensor), "Dry room")
        XCTAssertFalse(fixture.defaults.bool(forKey: fixture.legacy("absolute", "AlertIsOn", sensor: sensor)))
    }

    func testMissingTemperaturePreservesLegacyAlertAndRetriesWhenRecordArrives() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let sensor = try await fixture.sensor(record: false)
        fixture.enableLegacy("relative", sensor: sensor, lower: 0, upper: 100)
        do {
            try await fixture.alertMigration.migrate(); XCTFail("Missing temperature must remain retryable")
        } catch HumidityMigrationError.missingTemperature(let id) { XCTAssertEqual(id, sensor.id) }
        XCTAssertEqual(fixture.defaults.integer(forKey: "MigrationManagerAlertService.persistanceVersion"), 0)
        XCTAssertTrue(fixture.defaults.bool(forKey: fixture.legacy("relative", "AlertIsOn", sensor: sensor)))
        try await fixture.addRecord(sensor)
        try await RuuviMigrationRunner.migrate([fixture.alertMigration, fixture.humidityMigration])
        XCTAssertEqual(try XCTUnwrap(fixture.alerts.lowerRelativeHumidity(for: sensor)), 0, accuracy: 0.00001)
        XCTAssertEqual(try XCTUnwrap(fixture.alerts.upperRelativeHumidity(for: sensor)), 1, accuracy: 0.00001)
    }

    func testAbsoluteConversionWaitsForTemperatureWithoutConsumingCompletionFlag() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let sensor = try await fixture.sensor(record: false)
        fixture.alerts.register(
            type: .humidity(lower: .init(value: 3, unit: .absolute), upper: .init(value: 12, unit: .absolute)),
            ruuviTag: sensor)
        do {
            try await fixture.humidityMigration.migrate(); XCTFail("Expected missing temperature")
        } catch HumidityMigrationError.missingTemperature {}
        XCTAssertFalse(fixture.defaults.bool(forKey: "MigrationManagerToRH.migrated"))
        try await fixture.addRecord(sensor)
        try await fixture.humidityMigration.migrate()
        XCTAssertTrue(fixture.defaults.bool(forKey: "MigrationManagerToRH.migrated"))
        XCTAssertNotNil(fixture.alerts.lowerRelativeHumidity(for: sensor))
    }

    func testReadFailuresDoNotCompleteAnyHumidityMigration() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let migrations: [(RuuviMigration, String)] = [
            (fixture.alertMigration, "MigrationManagerAlertService.persistanceVersion"),
            (fixture.humidityMigration, "MigrationManagerToRH.migrated"),
            (fixture.boundsMigration, "RuuviMigrationFixRHAlerts.migrated"),
        ]
        fixture.storage.failReadAll = true
        for (migration, key) in migrations {
            do {
                try await migration.migrate(); XCTFail("A database failure must propagate")
            } catch is RuuviStorageError {}
            XCTAssertNil(fixture.defaults.object(forKey: key))
        }
        fixture.storage.failReadAll = false
        for (migration, key) in migrations {
            try await migration.migrate()
            XCTAssertNotNil(fixture.defaults.object(forKey: key))
        }
    }

    func testLatestRecordFailureLeavesLegacyAlertUntouched() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let sensor = try await fixture.sensor()
        fixture.enableLegacy("relative", sensor: sensor, lower: 20, upper: 80)
        fixture.storage.failLatest = true
        do { try await fixture.alertMigration.migrate(); XCTFail("Expected failed read") } catch is RuuviStorageError {}
        XCTAssertTrue(fixture.defaults.bool(forKey: fixture.legacy("relative", "AlertIsOn", sensor: sensor)))
        fixture.storage.failLatest = false
        try await fixture.alertMigration.migrate()
        fixture.storage.failLatest = true
        do { try await fixture.humidityMigration.migrate(); XCTFail("Expected failed read") } catch is RuuviStorageError
        {}
        XCTAssertFalse(fixture.defaults.bool(forKey: "MigrationManagerToRH.migrated"))
        fixture.storage.failLatest = false
        try await fixture.humidityMigration.migrate()
        XCTAssertEqual(try XCTUnwrap(fixture.alerts.lowerRelativeHumidity(for: sensor)), 0.2, accuracy: 0.00001)
    }

    func testNoLegacyDescriptionPreservesCurrentDescriptionAndDisabledAlertsStayDisabled() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let sensor = try await fixture.sensor(record: false)
        fixture.alerts.setHumidity(description: "Existing description", for: sensor)
        try await RuuviMigrationRunner.migrate([fixture.alertMigration, fixture.humidityMigration])
        XCTAssertEqual(fixture.alerts.relativeHumidityDescription(for: sensor), "Existing description")
        XCTAssertFalse(fixture.alerts.isOn(type: .relativeHumidity(lower: 0, upper: 1), for: sensor))
    }

    func testPercentBoundsFixOnlyLegacyValuesAndPreservesCurrentLimits() async throws {
        let fixture = try MigrationFixture()
        defer { fixture.close() }
        let legacy = try await fixture.sensor(record: false)
        let current = try await fixture.sensor(record: false)
        let unset = try await fixture.sensor(record: false)
        fixture.alerts.register(type: .relativeHumidity(lower: 20, upper: 100), ruuviTag: legacy)
        fixture.alerts.register(type: .relativeHumidity(lower: 0, upper: 1), ruuviTag: current)
        try await fixture.boundsMigration.migrate()
        XCTAssertEqual(fixture.alerts.lowerRelativeHumidity(for: legacy), 0.2)
        XCTAssertEqual(fixture.alerts.upperRelativeHumidity(for: legacy), 1)
        XCTAssertEqual(fixture.alerts.lowerRelativeHumidity(for: current), 0)
        XCTAssertEqual(fixture.alerts.upperRelativeHumidity(for: current), 1)
        XCTAssertNil(fixture.alerts.lowerRelativeHumidity(for: unset))
        fixture.alerts.setUpper(relativeHumidity: 50, ruuviTag: legacy)
        try await fixture.boundsMigration.migrate()
        XCTAssertEqual(fixture.alerts.upperRelativeHumidity(for: legacy), 50)
    }
}
