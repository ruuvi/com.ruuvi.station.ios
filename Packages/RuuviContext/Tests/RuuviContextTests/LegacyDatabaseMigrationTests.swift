import Foundation
import GRDB
import XCTest
@testable import RuuviContext
#if SWIFT_PACKAGE
    @testable import RuuviContextSQLite
#endif

final class LegacyDatabaseMigrationTests: XCTestCase {
    func testFirstSchemaUpgradePreservesSensorAndMeasurementsAndAddsSafeDefaults() throws {
        let fixture = try LegacyDatabaseFixture()
        defer { fixture.close() }
        try fixture.database.dbPool.write { db in
            try db.execute(
                sql: """
                    CREATE TABLE grdb_migrations(identifier TEXT NOT NULL PRIMARY KEY);
                    INSERT INTO grdb_migrations VALUES ('Create RuuviTagSQLite table');
                    CREATE TABLE ruuvi_tag_sensors (
                        id TEXT PRIMARY KEY, mac TEXT, luid TEXT, name TEXT NOT NULL,
                        version INTEGER NOT NULL, isConnectable BOOLEAN NOT NULL
                    );
                    INSERT INTO ruuvi_tag_sensors VALUES ('sensor', 'AA:BB:CC:DD:EE:FF', 'local', 'Kitchen', 5, 1);
                    CREATE TABLE ruuvi_tag_sensor_records (
                        id TEXT PRIMARY KEY, ruuviTagId TEXT NOT NULL, date DATETIME NOT NULL,
                        mac TEXT, rssi INTEGER, celsius DOUBLE, relativeHumidityInPercent DOUBLE,
                        hectopascals DOUBLE, accelerationX DOUBLE, accelerationY DOUBLE, accelerationZ DOUBLE,
                        volts DOUBLE, movementCounter INTEGER, measurementSequenceNumber INTEGER, txPower INTEGER
                    );
                    INSERT INTO ruuvi_tag_sensor_records(id, ruuviTagId, date, mac, celsius)
                        VALUES ('measurement', 'local', '2020-01-02 03:04:05.000', 'AA:BB:CC:DD:EE:FF', 21.5);
                    """)
        }
        try fixture.database.migrateIfNeeded()
        try fixture.database.migrateIfNeeded()
        try fixture.database.dbPool.read { db in
            let sensor = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM ruuvi_tag_sensors"))
            XCTAssertEqual(sensor["name"] as String, "Kitchen")
            XCTAssertEqual(sensor["mac"] as String, "AA:BB:CC:DD:EE:FF")
            XCTAssertEqual(sensor["version"] as Int, 5)
            XCTAssertEqual(sensor["isClaimed"] as Bool, false)
            XCTAssertEqual(sensor["isOwner"] as Bool, true)
            XCTAssertEqual(sensor["canShare"] as Bool, false)
            XCTAssertEqual(sensor["sharedTo"] as String, "")
            XCTAssertNil(sensor["lastUpdated"] as Date?)
            let record = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM ruuvi_tag_sensor_records"))
            XCTAssertEqual(record["celsius"] as Double, 21.5)
            XCTAssertEqual(record["ruuviTagId"] as String, "local")
            XCTAssertEqual(record["source"] as String, "unknown")
            for key in ["temperatureOffset", "humidityOffset", "pressureOffset"] {
                XCTAssertEqual(record[key] as Double, 0, key)
            }
            for key in [
                "pm1", "pm2_5", "pm4", "pm10", "co2", "voc", "nox", "luminance", "dbaInstant", "dbaAvg", "dbaPeak",
            ] {
                XCTAssertTrue(record.hasColumn(key), key)
                XCTAssertNil(record[key] as Double?, key)
            }
            for table in ["sensor_settings", "ruuvi_tag_sensor_record_latest", "user_settings"] {
                XCTAssertTrue(try db.tableExists(table), table)
            }
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ruuvi_tag_sensor_records"), 1)
        }
    }

    func testPreAirUpgradePreservesLatestReadingAndCalibrationWhileAddingNewSettings() throws {
        let fixture = try LegacyDatabaseFixture()
        defer { fixture.close() }
        try fixture.database.migrateIfNeeded()
        try fixture.database.dbPool.write { db in
            // Reconstruct the earlier on-disk layout, including a stored live reading and calibration.
            try db.execute(
                sql: """
                    INSERT INTO ruuvi_tag_sensor_record_latest(
                        id, ruuviTagId, date, source, version, celsius,
                        temperatureOffset, humidityOffset, pressureOffset
                    ) VALUES ('sensor', 'local', '2020-01-02 03:04:05.000', 'heartbeat', 5, 19.5, 1.5, 0, 0);
                    INSERT INTO sensor_settings(id, luid, temperatureOffset, humidityOffset, pressureOffset)
                        VALUES ('local-settings', 'local', 1.5, 0.1, 2);
                    """)
            let airColumns = [
                "pm1", "pm2_5", "pm4", "pm10", "co2", "voc", "nox", "luminance", "dbaAvg", "dbaPeak", "dbaInstant",
            ]
            for table in ["ruuvi_tag_sensor_records", "ruuvi_tag_sensor_record_latest"] {
                for column in airColumns {
                    try db.execute(sql: "ALTER TABLE \(table) DROP COLUMN \(column)")
                }
            }
            try db.execute(sql: "ALTER TABLE ruuvi_tag_sensor_record_latest DROP COLUMN version")
            try db.execute(sql: "ALTER TABLE ruuvi_tag_sensors DROP COLUMN lastUpdated")
            for column in [
                "displayOrder", "defaultDisplayOrder", "displayOrderLastUpdated", "defaultDisplayOrderLastUpdated",
                "description", "descriptionLastUpdated",
            ] {
                try db.execute(sql: "ALTER TABLE sensor_settings DROP COLUMN \(column)")
            }
            for migration in [
                "Create RuuviTagLatestDataSQLite version column",
                "Add new columns to RuuviTagDataSQLite and RuuviTagLatestDataSQLite",
                "Add new column to RuuviTagDataSQLite and RuuviTagLatestDataSQLite",
                "Add display order columns to SensorSettingsSQLite",
                "Add lastUpdated columns", "Add description columns to SensorSettingsSQLite",
            ] {
                try db.execute(sql: "DELETE FROM grdb_migrations WHERE identifier = ?", arguments: [migration])
            }
        }
        try fixture.database.migrateIfNeeded()
        try fixture.database.dbPool.read { db in
            let latest = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM ruuvi_tag_sensor_record_latest"))
            XCTAssertEqual(latest["id"] as String, "sensor")
            XCTAssertEqual(latest["celsius"] as Double, 19.5)
            XCTAssertEqual(latest["temperatureOffset"] as Double, 1.5)
            XCTAssertNil(latest["co2"] as Double?)
            XCTAssertNil(latest["version"] as Int?)
            let settings = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM sensor_settings"))
            XCTAssertEqual(settings["temperatureOffset"] as Double, 1.5)
            XCTAssertEqual(settings["humidityOffset"] as Double, 0.1)
            XCTAssertEqual(settings["pressureOffset"] as Double, 2)
            for key in [
                "displayOrder", "defaultDisplayOrder", "displayOrderLastUpdated", "defaultDisplayOrderLastUpdated",
                "description", "descriptionLastUpdated",
            ] {
                XCTAssertTrue(settings.hasColumn(key), key)
                XCTAssertNil(settings[key] as String?, key)
            }
        }
    }
    func testSubscriptionExpiryMigrationPreservesExistingPlansAndAllowsAnAbsentExpiry() throws {
        let fixture = try LegacyDatabaseFixture()
        defer { fixture.close() }
        try fixture.database.migrateIfNeeded()
        let original = try fixture.database.dbPool.write { db -> Row in
            let table = "ruuvi_cloud_sensor_subscription"
            let schema = try XCTUnwrap(String.fetchOne(
                db, sql: "SELECT sql FROM sqlite_master WHERE name = ?", arguments: [table]))
            try db.drop(table: table)
            try db.execute(sql: schema.replacingOccurrences(of: "\"endAt\" TEXT", with: "\"endAt\" TEXT NOT NULL"))
            XCTAssertTrue(try db.columns(in: table).contains { $0.name == "endAt" && $0.isNotNull })
            try db.execute(sql: "DELETE FROM grdb_migrations WHERE identifier = ?",
                           arguments: ["Allow optional cloud subscription expiry"])
            try db.execute(sql: """
                INSERT INTO ruuvi_cloud_sensor_subscription VALUES (
                    'original-subscription', 'original', 'Business', 1, 10, 365, 1, 100, 10,
                    1, 0, 1, 0, 1, 0, '2030-01-01');
                """)
            return try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM ruuvi_cloud_sensor_subscription"))
        }
        try fixture.database.migrateIfNeeded()
        try fixture.database.dbPool.write { db in
            XCTAssertEqual(try Row.fetchOne(db, sql: "SELECT * FROM ruuvi_cloud_sensor_subscription"), original)
            try db.execute(sql: """
                INSERT INTO ruuvi_cloud_sensor_subscription VALUES (
                    'new-subscription', 'new', 'Pro', 1, 10, 365, 1, 10, 10, 1, 1, 1, 1, 1, 1, NULL);
                """)
        }
        try fixture.database.migrateIfNeeded()
        try fixture.database.dbPool.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ruuvi_cloud_sensor_subscription"), 2)
            XCTAssertEqual(try Row.fetchOne(db, sql:
                "SELECT * FROM ruuvi_cloud_sensor_subscription WHERE macId = 'original'"), original)
            let added = try XCTUnwrap(Row.fetchOne(db, sql:
                "SELECT * FROM ruuvi_cloud_sensor_subscription WHERE macId = 'new'"))
            XCTAssertNil(added["endAt"] as String?)
            XCTAssertEqual(added["subscriptionName"] as String, "Pro")
            XCTAssertEqual(try String.fetchOne(db, sql: "PRAGMA integrity_check"), "ok")
            XCTAssertFalse(try db.tableExists("ruuvi_cloud_sensor_subscription_expiry_migration"))
        }
    }

}

private final class LegacyDatabaseFixture {
    let directory: URL
    let database: SQLiteGRDBDatabase
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        database = try SQLiteGRDBDatabase(path: directory.appendingPathComponent("legacy.sqlite").path)
    }
    func close() {
        try? database.dbPool.close()
        try? FileManager.default.removeItem(at: directory)
    }
}
