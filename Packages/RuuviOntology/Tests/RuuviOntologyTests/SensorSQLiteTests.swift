import Foundation
import GRDB
@testable import RuuviOntology
#if SWIFT_PACKAGE
    @testable import RuuviOntologySQLite
#endif
import XCTest

final class SensorSQLiteTests: XCTestCase {
    func testSettingsRoundTripPreservesCalibrationUnicodeOrderingAndIndependentUpdateDates() throws {
        let queue = try DatabaseQueue()
        let settings = SensorSettingsStruct(
            luid: "local".luid, macId: "AA:BB:CC:DD:EE:FF".mac, temperatureOffset: -1.5,
            humidityOffset: 0.025, pressureOffset: 3.25, description: "Sauna 🌡️\n\"upstairs\"",
            displayOrder: ["temperature_celsius", "co2", "unicode_🌡️"], defaultDisplayOrder: false,
            displayOrderLastUpdated: Date(timeIntervalSince1970: 100),
            defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 200),
            descriptionLastUpdated: Date(timeIntervalSince1970: 300))
        try queue.write { db in
            try SensorSettingsSQLite.createTable(in: db)
            try settings.sqlite.insert(db)
            let stored = try XCTUnwrap(SensorSettingsSQLite.fetchOne(db, key: settings.id))
            XCTAssertEqual(stored, settings.sqlite)
            XCTAssertEqual(stored.sensorSettings.sqlite, settings.sqlite)
            let moved = stored.sensorSettings.with(macId: "AA:BB:CC:11:22:33".mac).sqlite
            XCTAssertEqual(moved.description, stored.description)
            XCTAssertEqual(moved.displayOrder, stored.displayOrder)
            XCTAssertEqual(moved.defaultDisplayOrderLastUpdated, stored.defaultDisplayOrderLastUpdated)
            XCTAssertEqual(moved.id, "AA:BB:CC:11:22:33-settings")
            XCTAssertNotEqual(moved, stored)
            try moved.insert(db)
            XCTAssertEqual(try SensorSettingsSQLite.fetchCount(db), 2)
        }
    }

    func testOptionalSettingsAndMalformedStoredOrderDoNotDropOtherData() throws {
        let queue = try DatabaseQueue()
        let settings = SensorSettingsSQLite(
            luid: "local".luid, macId: nil, temperatureOffset: nil, humidityOffset: nil, pressureOffset: nil)
        try queue.write { db in
            try SensorSettingsSQLite.createTable(in: db)
            try settings.insert(db)
            XCTAssertEqual(try SensorSettingsSQLite.fetchOne(db, key: settings.id), settings)
            try db.execute(
                sql: "UPDATE sensor_settings SET displayOrder = ?, description = ?",
                arguments: ["{broken", "keep"])
            let restored = try XCTUnwrap(SensorSettingsSQLite.fetchOne(db))
            XCTAssertNil(restored.displayOrder)
            XCTAssertEqual(restored.description, "keep")
            XCTAssertEqual(restored.luid?.value, "local")
            XCTAssertNil(restored.macId)
            var macOnly = settings
            macOnly.luid = nil
            macOnly.macId = "AA:BB:CC:DD:EE:FF".mac
            try macOnly.insert(db)
            XCTAssertEqual(try SensorSettingsSQLite.fetchOne(db, key: macOnly.id), macOnly)
        }
    }

    func testDisplayOrderCodecKeepsEmptyAndMissingOrdersDistinctAndRejectsInvalidShapes() {
        XCTAssertNil(SensorSettingsSQLite.encodeDisplayOrder(nil))
        XCTAssertNil(SensorSettingsSQLite.encodeDisplayOrder([]))
        XCTAssertEqual(SensorSettingsSQLite.decodeDisplayOrder("[]"), [])
        for raw in ["", "null", "{}", "[1]", "[null]", "broken", #""temperature""#] {
            XCTAssertNil(SensorSettingsSQLite.decodeDisplayOrder(raw), raw)
        }
        let codes = ["", "🌡️", "a\"b", "co2", "co2", "\n"]
        XCTAssertEqual(
            SensorSettingsSQLite.encodeDisplayOrder(codes).flatMap(SensorSettingsSQLite.decodeDisplayOrder), codes)
    }

    func testEverySettingsFieldParticipatesInChangeDetection() {
        let settings = SensorSettingsSQLite(
            luid: "local".luid, macId: "AA:BB:CC:DD:EE:FF".mac, temperatureOffset: 1,
            humidityOffset: 0.02, pressureOffset: 3, description: "Name",
            displayOrder: ["co2"], defaultDisplayOrder: true,
            displayOrderLastUpdated: Date(timeIntervalSince1970: 1),
            defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 2),
            descriptionLastUpdated: Date(timeIntervalSince1970: 3))
        let changes: [(inout SensorSettingsSQLite) -> Void] = [
            { $0.luid = nil }, { $0.macId = nil }, { $0.temperatureOffset = nil },
            { $0.humidityOffset = nil }, { $0.pressureOffset = nil }, { $0.description = nil },
            { $0.displayOrder = nil }, { $0.defaultDisplayOrder = false },
            { $0.displayOrderLastUpdated = nil }, { $0.defaultDisplayOrderLastUpdated = nil },
            { $0.descriptionLastUpdated = nil },
        ]
        for change in changes {
            var changed = settings
            change(&changed)
            XCTAssertNotEqual(changed, settings)
        }
    }

    func testSubscriptionReassignmentAndDatabaseRoundTripPreserveEveryEntitlement() throws {
        let original = modelSubscription()
        let moved = original.with(macId: "AA:BB:CC:11:22:33").sqlite
        var expected = original.sqlite
        expected.macId = "AA:BB:CC:11:22:33"
        XCTAssertEqual(moved, expected)
        XCTAssertEqual(moved.id, "AA:BB:CC:11:22:33-subscription")
        let queue = try DatabaseQueue()
        try queue.write { db in
            try RuuviCloudSensorSubscriptionSQLite.createTable(in: db)
            try moved.insert(db)
            let restored = try XCTUnwrap(RuuviCloudSensorSubscriptionSQLite.fetchOne(db, key: moved.id))
            XCTAssertEqual(restored, expected)
            let changes: [(inout RuuviCloudSensorSubscriptionSQLite) -> Void] = [
                { $0.macId = nil }, { $0.subscriptionName = nil }, { $0.isActive = false },
                { $0.maxClaims = 0 }, { $0.maxHistoryDays = 0 }, { $0.maxResolutionMinutes = 0 },
                { $0.maxShares = 0 }, { $0.maxSharesPerSensor = 0 }, { $0.delayedAlertAllowed = false },
                { $0.emailAlertAllowed = true }, { $0.offlineAlertAllowed = false },
                { $0.pdfExportAllowed = true }, { $0.pushAlertAllowed = false },
                { $0.telegramAlertAllowed = true }, { $0.endAt = nil },
            ]
            for change in changes {
                var changed = restored
                change(&changed)
                XCTAssertNotEqual(changed, restored)
            }
            var expired = restored
            expired.isActive = false
            try expired.insert(db)
            XCTAssertEqual(try RuuviCloudSensorSubscriptionSQLite.fetchCount(db), 1)
            XCTAssertEqual(try RuuviCloudSensorSubscriptionSQLite.fetchOne(db, key: moved.id), expired)
        }
    }
}
