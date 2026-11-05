import BTKit
import Foundation
import GRDB
import XCTest
@testable import RuuviOntology
#if SWIFT_PACKAGE
    @testable import RuuviOntologySQLite
#endif

final class AccelerationUnitTests: XCTestCase {
    func testBluetoothAccelerationIsExpressedInGravityAndRequiresEveryAxis() throws {
        // RAWv2's documented example is 4 mg, -4 mg, 1036 mg. BTKit supplies values in g.
        var data = RuuviData5(
            uuid: "local", rssi: -40, isConnectable: true, version: 5, humidity: 50, temperature: 20,
            pressure: 1000, accelerationX: 0.004, accelerationY: -0.004, accelerationZ: 1.036,
            voltage: 3, movementCounter: 1, measurementSequenceNumber: 2, txPower: 4,
            mac: "AA:BB:CC:DD:EE:FF")
        let acceleration = try XCTUnwrap(RuuviTag.v5(data).acceleration)
        XCTAssertEqual(acceleration.x.converted(to: .gravity).value, 0.004, accuracy: 0.000001)
        XCTAssertEqual(acceleration.y.converted(to: .gravity).value, -0.004, accuracy: 0.000001)
        XCTAssertEqual(acceleration.z.converted(to: .gravity).value, 1.036, accuracy: 0.000001)
        XCTAssertEqual(acceleration.z.converted(to: .metersPerSecondSquared).value, 10.16316, accuracy: 0.000001)
        let original = data
        for axis in 0..<3 {
            data = original
            if axis == 0 { data.accelerationX = nil }
            if axis == 1 { data.accelerationY = nil }
            if axis == 2 { data.accelerationZ = nil }
            XCTAssertNil(RuuviTag.v5(data).acceleration)
        }
    }

    func testLegacyHistoryAndLatestRowsKeepTheirPhysicalAcceleration() throws {
        let queue = try DatabaseQueue()
        let record = modelRecord()
        try queue.write { db in
            try RuuviTagDataSQLite.createTable(in: db)
            try RuuviTagLatestDataSQLite.createTable(in: db)
            try record.sqlite.insert(db)
            try record.latest.insert(db)
            for table in [RuuviTagDataSQLite.databaseTableName, RuuviTagLatestDataSQLite.databaseTableName] {
                try db.execute(sql: "UPDATE \(table) SET accelerationX = 0.004, accelerationY = -0.004, accelerationZ = 1.036")
            }
            let history = try XCTUnwrap(RuuviTagDataSQLite.fetchOne(db))
            let latest = try XCTUnwrap(RuuviTagLatestDataSQLite.fetchOne(db))
            for acceleration in [history.acceleration, latest.acceleration] {
                let value = try XCTUnwrap(acceleration)
                XCTAssertEqual(value.x.converted(to: .gravity).value, 0.004, accuracy: 0.000001)
                XCTAssertEqual(value.y.converted(to: .gravity).value, -0.004, accuracy: 0.000001)
                XCTAssertEqual(value.z.converted(to: .gravity).value, 1.036, accuracy: 0.000001)
            }
            XCTAssertEqual(history.date, record.date)
            XCTAssertEqual(latest.date, record.date)
            XCTAssertEqual(history.temperature, record.temperature)
            XCTAssertEqual(latest.temperature, record.temperature)
        }
    }

    func testSIAndGravityInputsUseTheSameLegacyDatabaseUnits() throws {
        for unit in [UnitAcceleration.gravity, .metersPerSecondSquared] {
            let queue = try DatabaseQueue()
            var record = modelRecord()
            record.acceleration = .init(
                x: .init(value: -1, unit: .gravity).converted(to: unit),
                y: .init(value: 0, unit: .gravity).converted(to: unit),
                z: .init(value: 1, unit: .gravity).converted(to: unit))
            try queue.write { db in
                try RuuviTagDataSQLite.createTable(in: db)
                try RuuviTagLatestDataSQLite.createTable(in: db)
                try record.sqlite.insert(db)
                try record.latest.insert(db)
                for table in [RuuviTagDataSQLite.databaseTableName, RuuviTagLatestDataSQLite.databaseTableName] {
                    let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM \(table)"))
                    XCTAssertEqual(row["accelerationX"] as Double, -1, accuracy: 0.000001)
                    XCTAssertEqual(row["accelerationY"] as Double, 0, accuracy: 0.000001)
                    XCTAssertEqual(row["accelerationZ"] as Double, 1, accuracy: 0.000001)
                }
                XCTAssertEqual(try RuuviTagDataSQLite.fetchOne(db)?.acceleration, record.acceleration)
                XCTAssertEqual(try RuuviTagLatestDataSQLite.fetchOne(db)?.acceleration, record.acceleration)
            }
        }
    }
}
