import Foundation
import GRDB
import RuuviOntology

final class SQLiteContextGRDB: SQLiteContext, @unchecked Sendable {
    let database: GRDBDatabase = SQLiteGRDBDatabase.shared
}

public protocol DatabaseService {
    associatedtype Entity: PersistableRecord

    var database: GRDBDatabase { get }
}

final class SQLiteGRDBDatabase: GRDBDatabase, @unchecked Sendable {
    static let shared: SQLiteGRDBDatabase = {
        let instance = try! SQLiteGRDBDatabase()
        return instance
    }()

    static var databasePath: String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(
            .documentDirectory,
            .userDomainMask,
            true
        ).first! as NSString
        let databasePath = documentsPath.appendingPathComponent("grdb.sqlite")
        return databasePath
    }

    var dbPath: String {
        Self.databasePath
    }

    private(set) var dbPool: DatabasePool

    private init() throws {
        var configuration = Configuration()
        configuration.qos = .default
        let pool = try DatabasePool(path: SQLiteGRDBDatabase.databasePath, configuration: configuration)
        try pool.write { database in
            try database.execute(sql: "PRAGMA auto_vacuum = FULL")
        }

        dbPool = pool
    }

    private func recreate() {
        do {
            try FileManager.default.removeItem(atPath: SQLiteGRDBDatabase.databasePath)
            dbPool = try DatabasePool(path: SQLiteGRDBDatabase.databasePath)
        } catch {
            print(error.localizedDescription)
        }
    }
}

extension SQLiteGRDBDatabase {
    func migrateIfNeeded() {
        do {
            try migrate(dbPool: dbPool)
        } catch {
            recreate()
            try! migrate(dbPool: dbPool)
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func migrate(dbPool: DatabasePool) throws {
        var migrator = GRDB.DatabaseMigrator()

        // v1
        migrator.registerMigration("Create RuuviTagSQLite table") { db in
            try RuuviTagSQLite.createTable(in: db)
            try RuuviTagDataSQLite.createTable(in: db)
        }

        // v2
        migrator.registerMigration("Add isClaimedColumn column") { db in
            guard try db.columns(in: RuuviTagSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagSQLite.isClaimedColumn.name }) == false
            else {
                return
            }
            try db.alter(table: RuuviTagSQLite.databaseTableName) { t in
                t.add(column: RuuviTagSQLite.isClaimedColumn.name, .boolean)
                    .notNull()
                    .defaults(to: false)
                t.add(column: RuuviTagSQLite.isOwnerColumn.name, .boolean)
                    .notNull()
                    .defaults(to: true)
                t.add(column: RuuviTagSQLite.owner.name, .text)
            }
        }

        // v3
        migrator.registerMigration("Create SensorSettingsSQLite table") { db in
            guard try db.tableExists(SensorSettingsSQLite.databaseTableName) == false else { return }
            try SensorSettingsSQLite.createTable(in: db)

            guard try db.columns(in: RuuviTagDataSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagDataSQLite.temperatureOffsetColumn.name }) == false
            else {
                return
            }
            try db.alter(table: RuuviTagDataSQLite.databaseTableName, body: { t in
                t.add(column: RuuviTagDataSQLite.temperatureOffsetColumn.name, .double)
                    .notNull().defaults(to: 0.0)
                t.add(column: RuuviTagDataSQLite.humidityOffsetColumn.name, .double)
                    .notNull().defaults(to: 0.0)
                t.add(column: RuuviTagDataSQLite.pressureOffsetColumn.name, .double)
                    .notNull().defaults(to: 0.0)
            })
        }

        // v4
        migrator.registerMigration("Create RuuviTagDataSQLite source column") { db in
            guard try db.columns(in: RuuviTagDataSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagDataSQLite.sourceColumn.name }) == false
            else {
                return
            }
            try db.alter(table: RuuviTagDataSQLite.databaseTableName, body: { t in
                t.add(column: RuuviTagDataSQLite.sourceColumn.name, .text)
                    .notNull().defaults(to: "unknown")
            })
        }

        // v5
        migrator.registerMigration("Create RuuviTagDataSQLite luid column") { db in
            guard try db.columns(in: RuuviTagDataSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagDataSQLite.luidColumn.name }) == false
            else {
                return
            }
            try db.alter(table: RuuviTagDataSQLite.databaseTableName, body: { t in
                t.add(column: RuuviTagDataSQLite.luidColumn.name, .text)
            })
        }
        // v6
        migrator.registerMigration("Create RuuviTagSQLite isCloudSensor column") { db in
            guard try db.columns(in: RuuviTagSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagSQLite.isCloudSensor.name }) == false
            else {
                return
            }
            try db.alter(table: RuuviTagSQLite.databaseTableName, body: { t in
                t.add(column: RuuviTagSQLite.isCloudSensor.name, .boolean)
            })
        }
        // v7
        migrator.registerMigration("Create RuuviTagSQLite firmwareVersion column") { db in
            guard try db.columns(in: RuuviTagSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagSQLite.firmwareVersionColumn.name }) == false
            else {
                return
            }
            try db.alter(table: RuuviTagSQLite.databaseTableName, body: { t in
                t.add(column: RuuviTagSQLite.firmwareVersionColumn.name, .text)
            })
        }
        // v8
        migrator.registerMigration("Create RuuviTagLatestDataSQLite table") { db in
            try RuuviTagLatestDataSQLite.createTable(in: db)
        }
        // v8
        migrator.registerMigration("Create RuuviCloudRequestQueueSQLite table") { db in
            try RuuviCloudQueuedRequestSQLite.createTable(in: db)
        }
        // v9
        migrator.registerMigration("Create RuuviTagSQLite canShare column") { db in
            guard try db.columns(in: RuuviTagSQLite.databaseTableName)
                .contains(
                    where: { $0.name == RuuviTagSQLite.canShareColumn.name }
                ) == false
            else {
                return
            }
            try db.alter(table: RuuviTagSQLite.databaseTableName, body: { t in
                t.add(
                    column: RuuviTagSQLite.canShareColumn.name, .boolean
                ).defaults(to: false)
            })
        }
        // v10
        migrator.registerMigration("Create RuuviTagSQLite sharedTo column") { db in
            guard try db.columns(in: RuuviTagSQLite.databaseTableName)
                .contains(
                    where: { $0.name == RuuviTagSQLite.sharedToColumn.name }
                ) == false
            else {
                return
            }
            try db.alter(table: RuuviTagSQLite.databaseTableName, body: { t in
                t.add(column: RuuviTagSQLite.sharedToColumn.name, .text)
                    .defaults(to: "")
            })
        }
        // v11
        migrator.registerMigration("Create RuuviTagSQLite ownersPlan column") { db in
            guard try db.columns(in: RuuviTagSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagSQLite.ownersPlan.name }) == false
            else {
                return
            }
            try db.alter(table: RuuviTagSQLite.databaseTableName, body: { t in
                t.add(column: RuuviTagSQLite.ownersPlan.name, .text)
            })
        }
        // v12
        migrator.registerMigration("Create RuuviTagSQLite maxHistoryDays column") { db in
            guard try db.columns(in: RuuviTagSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagSQLite.maxHistoryDaysColumn.name }) == false
            else {
                return
            }
            try db.alter(table: RuuviTagSQLite.databaseTableName, body: { t in
                t.add(column: RuuviTagSQLite.maxHistoryDaysColumn.name, .integer)
            })
        }
        // v13
        migrator.registerMigration("Create RuuviCloudSensorSubscription table") { db in
            try RuuviCloudSensorSubscriptionSQLite.createTable(in: db)
        }
        // v14
        migrator.registerMigration("Create RuuviTagSQLite serviceUUID column") { db in
            guard try db.columns(in: RuuviTagSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagSQLite.serviceUUIDColumn.name }) == false
            else {
                return
            }
            try db.alter(table: RuuviTagSQLite.databaseTableName, body: { t in
                t.add(column: RuuviTagSQLite.serviceUUIDColumn.name, .text)
            })
        }
        // v15
        migrator.registerMigration("Create RuuviTagDataSQLite version column") { db in
            guard try db.columns(in: RuuviTagDataSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagDataSQLite.versionColumn.name }) == false
            else {
                return
            }
            try db.alter(table: RuuviTagDataSQLite.databaseTableName, body: { t in
                t.add(column: RuuviTagDataSQLite.versionColumn.name, .integer)
            })
        }
        migrator.registerMigration("Create RuuviTagLatestDataSQLite version column") { db in
            guard try db.columns(in: RuuviTagLatestDataSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagLatestDataSQLite.versionColumn.name }) == false
            else {
                return
            }
            try db.alter(table: RuuviTagLatestDataSQLite.databaseTableName, body: { t in
                t.add(column: RuuviTagLatestDataSQLite.versionColumn.name, .integer)
            })
        }

        // v16
        migrator.registerMigration("Add new columns to RuuviTagDataSQLite and RuuviTagLatestDataSQLite") { db in
            // For RuuviTagDataSQLite
            if try db.columns(in: RuuviTagDataSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagDataSQLite.pm1Column.name }) == false {
                try db.alter(table: RuuviTagDataSQLite.databaseTableName, body: { t in
                    t.add(column: RuuviTagDataSQLite.pm1Column.name, .double)
                    t.add(column: RuuviTagDataSQLite.pm25Column.name, .double)
                    t.add(column: RuuviTagDataSQLite.pm4Column.name, .double)
                    t.add(column: RuuviTagDataSQLite.pm10Column.name, .double)
                    t.add(column: RuuviTagDataSQLite.co2Column.name, .double)
                    t.add(column: RuuviTagDataSQLite.vocColumn.name, .double)
                    t.add(column: RuuviTagDataSQLite.noxColumn.name, .double)
                    t.add(column: RuuviTagDataSQLite.luminanceColumn.name, .double)
                    t.add(column: RuuviTagDataSQLite.dbaAvgColumn.name, .double)
                    t.add(column: RuuviTagDataSQLite.dbaPeakColumn.name, .double)
                })
            }

            // For RuuviTagLatestDataSQLite
            if try db.columns(in: RuuviTagLatestDataSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagLatestDataSQLite.pm1Column.name }) == false {
                try db.alter(table: RuuviTagLatestDataSQLite.databaseTableName, body: { t in
                    t.add(column: RuuviTagLatestDataSQLite.pm1Column.name, .double)
                    t.add(column: RuuviTagLatestDataSQLite.pm25Column.name, .double)
                    t.add(column: RuuviTagLatestDataSQLite.pm4Column.name, .double)
                    t.add(column: RuuviTagLatestDataSQLite.pm10Column.name, .double)
                    t.add(column: RuuviTagLatestDataSQLite.co2Column.name, .double)
                    t.add(column: RuuviTagLatestDataSQLite.vocColumn.name, .double)
                    t.add(column: RuuviTagLatestDataSQLite.noxColumn.name, .double)
                    t.add(column: RuuviTagLatestDataSQLite.luminanceColumn.name, .double)
                    t.add(column: RuuviTagLatestDataSQLite.dbaAvgColumn.name, .double)
                    t.add(column: RuuviTagLatestDataSQLite.dbaPeakColumn.name, .double)
                })
            }
        }

        // v17
        migrator.registerMigration("Add new column to RuuviTagDataSQLite and RuuviTagLatestDataSQLite") { db in
            // For RuuviTagDataSQLite
            if try db.columns(in: RuuviTagDataSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagDataSQLite.dbaInstantColumn.name }) == false {
                try db.alter(table: RuuviTagDataSQLite.databaseTableName, body: { t in
                    t.add(column: RuuviTagDataSQLite.dbaInstantColumn.name, .double)
                })
            }

            // For RuuviTagLatestDataSQLite
            if try db.columns(in: RuuviTagLatestDataSQLite.databaseTableName)
                .contains(where: { $0.name == RuuviTagLatestDataSQLite.dbaInstantColumn.name }) == false {
                try db.alter(table: RuuviTagLatestDataSQLite.databaseTableName, body: { t in
                    t.add(column: RuuviTagDataSQLite.dbaInstantColumn.name, .double)
                })
            }
        }

        // v18
        migrator.registerMigration("Add display order columns to SensorSettingsSQLite") { db in
            guard try db.columns(in: SensorSettingsSQLite.databaseTableName)
                .contains(where: { $0.name == SensorSettingsSQLite.displayOrderColumn.name }) == false
            else {
                return
            }
            try db.alter(table: SensorSettingsSQLite.databaseTableName, body: { t in
                t.add(column: SensorSettingsSQLite.displayOrderColumn.name, .text)
                t.add(column: SensorSettingsSQLite.defaultDisplayOrderColumn.name, .boolean)
            })
        }

        try migrator.migrate(dbPool)
    }
}
