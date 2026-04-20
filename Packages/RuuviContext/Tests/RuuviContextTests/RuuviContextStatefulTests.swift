@testable import RuuviContext
import GRDB
import RuuviOntology
import XCTest

final class RuuviContextStatefulTests: XCTestCase {
    func testSQLiteContextFactoryCreatesGRDBContext() {
        let context = SQLiteContextFactoryGRDB().create()

        XCTAssertTrue(context is SQLiteContextGRDB)
    }

    func testSQLiteContextUsesSharedDatabasePath() {
        let context = SQLiteContextFactoryGRDB().create()

        XCTAssertEqual(context.database.dbPath, SQLiteGRDBDatabase.databasePath)
        XCTAssertTrue(context.database.dbPath.hasSuffix("grdb.sqlite"))
    }

    func testSQLiteContextCanWrapInjectedDatabase() throws {
        let database = try SQLiteGRDBDatabase(path: temporaryDatabasePath())

        let context = SQLiteContextGRDB(database: database)

        XCTAssertEqual(context.database.dbPath, database.dbPath)
    }

    func testSQLiteDatabaseMigratesExpectedTablesAndColumns() throws {
        let path = temporaryDatabasePath()
        let database = try SQLiteGRDBDatabase(path: path)

        database.migrateIfNeeded()

        XCTAssertTrue(try database.hasTable(named: RuuviTagSQLite.databaseTableName))
        XCTAssertTrue(try database.hasTable(named: RuuviTagDataSQLite.databaseTableName))
        XCTAssertTrue(try database.hasTable(named: SensorSettingsSQLite.databaseTableName))
        XCTAssertTrue(try database.hasTable(named: RuuviTagLatestDataSQLite.databaseTableName))
        XCTAssertTrue(try database.hasTable(named: RuuviCloudQueuedRequestSQLite.databaseTableName))
        XCTAssertTrue(try database.hasTable(named: RuuviCloudSensorSubscriptionSQLite.databaseTableName))

        let tagColumns = try database.columnNames(in: RuuviTagSQLite.databaseTableName)
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.isClaimedColumn.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.firmwareVersionColumn.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.maxHistoryDaysColumn.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.serviceUUIDColumn.name))

        let dataColumns = try database.columnNames(in: RuuviTagDataSQLite.databaseTableName)
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.temperatureOffsetColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.humidityOffsetColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.pressureOffsetColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.luidColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.versionColumn.name))

        let latestColumns = try database.columnNames(in: RuuviTagLatestDataSQLite.databaseTableName)
        XCTAssertTrue(latestColumns.contains(RuuviTagLatestDataSQLite.versionColumn.name))
    }

    func testSQLiteDatabaseRecreatesInvalidFileBeforeMigrating() throws {
        let path = temporaryDatabasePath()
        var validations = 0
        let database = try SQLiteGRDBDatabase(
            path: path,
            validator: { _ in
                validations += 1
                if validations == 1 {
                    throw NSError(domain: "RuuviContextTests", code: 1)
                }
            }
        )

        database.migrateIfNeeded()

        XCTAssertTrue(try database.hasTable(named: RuuviTagSQLite.databaseTableName))
        XCTAssertTrue(try database.hasTable(named: RuuviTagLatestDataSQLite.databaseTableName))
        XCTAssertGreaterThanOrEqual(validations, 1)
    }

    func testSQLiteDatabaseSkipsEarlyColumnMigrationsWhenLegacySchemaAlreadyContainsThem() throws {
        let database = try seededDatabase(appliedMigrationCount: 1) { db in
            try createMinimalTagTable(in: db)
            try createMinimalDataTable(in: db)
            try addLegacyTagColumns(in: db)
            try addLegacyDataColumns(in: db)
        }

        database.migrateIfNeeded()

        XCTAssertTrue(try database.hasTable(named: SensorSettingsSQLite.databaseTableName))
        XCTAssertTrue(try database.hasTable(named: RuuviTagLatestDataSQLite.databaseTableName))
        XCTAssertTrue(try database.hasTable(named: RuuviCloudQueuedRequestSQLite.databaseTableName))
        XCTAssertTrue(try database.hasTable(named: RuuviCloudSensorSubscriptionSQLite.databaseTableName))
        let latestColumns = try database.columnNames(in: RuuviTagLatestDataSQLite.databaseTableName)
        XCTAssertTrue(latestColumns.contains(RuuviTagLatestDataSQLite.versionColumn.name))
        XCTAssertTrue(latestColumns.contains(RuuviTagLatestDataSQLite.pm1Column.name))
        XCTAssertTrue(latestColumns.contains(RuuviTagLatestDataSQLite.dbaInstantColumn.name))
    }

    func testSQLiteDatabaseAddsMissingColumnsToMinimalLegacyTagAndDataTables() throws {
        let database = try seededDatabase(appliedMigrationCount: 1) { db in
            try createMinimalTagTable(in: db)
            try createMinimalDataTable(in: db)
        }

        database.migrateIfNeeded()

        let tagColumns = try database.columnNames(in: RuuviTagSQLite.databaseTableName)
        let dataColumns = try database.columnNames(in: RuuviTagDataSQLite.databaseTableName)
        let latestColumns = try database.columnNames(in: RuuviTagLatestDataSQLite.databaseTableName)

        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.isClaimedColumn.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.isOwnerColumn.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.owner.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.isCloudSensor.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.firmwareVersionColumn.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.canShareColumn.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.sharedToColumn.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.ownersPlan.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.maxHistoryDaysColumn.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.serviceUUIDColumn.name))
        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.lastUpdatedColumn.name))

        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.temperatureOffsetColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.humidityOffsetColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.pressureOffsetColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.sourceColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.luidColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.versionColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.pm1Column.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.pm25Column.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.pm4Column.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.pm10Column.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.co2Column.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.vocColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.noxColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.luminanceColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.dbaAvgColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.dbaPeakColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.dbaInstantColumn.name))

        XCTAssertTrue(latestColumns.contains(RuuviTagLatestDataSQLite.versionColumn.name))
    }

    func testSQLiteDatabaseSkipsLateMigrationsWhenCurrentColumnsAlreadyExist() throws {
        let database = try seededDatabase(appliedMigrationCount: 14) { db in
            try createMinimalTagTable(in: db)
            try createMinimalDataTable(in: db)
            try SensorSettingsSQLite.createTable(in: db)
            try RuuviTagLatestDataSQLite.createTable(in: db)
            try RuuviCloudQueuedRequestSQLite.createTable(in: db)
            try RuuviCloudSensorSubscriptionSQLite.createTable(in: db)
            try addLegacyTagColumns(in: db)
            try addLegacyDataColumns(in: db)
        }

        database.migrateIfNeeded()

        let tagColumns = try database.columnNames(in: RuuviTagSQLite.databaseTableName)
        let dataColumns = try database.columnNames(in: RuuviTagDataSQLite.databaseTableName)
        let latestColumns = try database.columnNames(in: RuuviTagLatestDataSQLite.databaseTableName)
        let sensorSettingsColumns = try database.columnNames(in: SensorSettingsSQLite.databaseTableName)

        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.lastUpdatedColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.dbaInstantColumn.name))
        XCTAssertTrue(latestColumns.contains(RuuviTagLatestDataSQLite.dbaInstantColumn.name))
        XCTAssertTrue(sensorSettingsColumns.contains(SensorSettingsSQLite.displayOrderColumn.name))
        XCTAssertTrue(sensorSettingsColumns.contains(SensorSettingsSQLite.descriptionLastUpdatedColumn.name))
    }

    func testSQLiteDatabaseAddsMissingColumnsToLegacyLatestDataAndSensorSettingsTables() throws {
        let database = try seededDatabase(appliedMigrationCount: 14) { db in
            try createMinimalTagTable(in: db)
            try createMinimalDataTable(in: db)
            try createMinimalLatestDataTable(in: db)
            try createMinimalSensorSettingsTable(in: db)
            try RuuviCloudQueuedRequestSQLite.createTable(in: db)
            try RuuviCloudSensorSubscriptionSQLite.createTable(in: db)
            try addTagColumnsThroughV14(in: db)
            try addDataColumnsThroughV5(in: db)
        }

        database.migrateIfNeeded()

        let tagColumns = try database.columnNames(in: RuuviTagSQLite.databaseTableName)
        let dataColumns = try database.columnNames(in: RuuviTagDataSQLite.databaseTableName)
        let latestColumns = try database.columnNames(in: RuuviTagLatestDataSQLite.databaseTableName)
        let sensorSettingsColumns = try database.columnNames(in: SensorSettingsSQLite.databaseTableName)

        XCTAssertTrue(tagColumns.contains(RuuviTagSQLite.lastUpdatedColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.versionColumn.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.pm1Column.name))
        XCTAssertTrue(dataColumns.contains(RuuviTagDataSQLite.dbaInstantColumn.name))
        XCTAssertTrue(latestColumns.contains(RuuviTagLatestDataSQLite.versionColumn.name))
        XCTAssertTrue(latestColumns.contains(RuuviTagLatestDataSQLite.pm1Column.name))
        XCTAssertTrue(latestColumns.contains(RuuviTagLatestDataSQLite.dbaInstantColumn.name))
        XCTAssertTrue(sensorSettingsColumns.contains(SensorSettingsSQLite.displayOrderColumn.name))
        XCTAssertTrue(sensorSettingsColumns.contains(SensorSettingsSQLite.defaultDisplayOrderColumn.name))
        XCTAssertTrue(sensorSettingsColumns.contains(SensorSettingsSQLite.displayOrderLastUpdatedColumn.name))
        XCTAssertTrue(sensorSettingsColumns.contains(SensorSettingsSQLite.defaultDisplayOrderLastUpdatedColumn.name))
        XCTAssertTrue(sensorSettingsColumns.contains(SensorSettingsSQLite.descriptionColumn.name))
        XCTAssertTrue(sensorSettingsColumns.contains(SensorSettingsSQLite.descriptionLastUpdatedColumn.name))
    }

    private func temporaryDatabasePath() -> String {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileURL = directory.appendingPathComponent("ruuvi-context-\(UUID().uuidString).sqlite")
        return fileURL.path
    }
}

private func seededDatabase(
    appliedMigrationCount: Int,
    configure: (Database) throws -> Void
) throws -> SQLiteGRDBDatabase {
    let database = try SQLiteGRDBDatabase(path: temporaryDatabasePath())
    try database.dbPool.write { db in
        try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
        for migration in contextMigrationNames.prefix(appliedMigrationCount) {
            try db.execute(
                sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)",
                arguments: [migration]
            )
        }
        try configure(db)
    }
    return database
}

private func addLegacyTagColumns(in db: Database) throws {
    try addTagColumnsThroughV14(in: db)
    try db.alter(table: RuuviTagSQLite.databaseTableName) { table in
        table.add(column: RuuviTagSQLite.lastUpdatedColumn.name, .datetime)
    }
}

private func addTagColumnsThroughV14(in db: Database) throws {
    try db.alter(table: RuuviTagSQLite.databaseTableName) { table in
        table.add(column: RuuviTagSQLite.isClaimedColumn.name, .boolean).notNull().defaults(to: false)
        table.add(column: RuuviTagSQLite.isOwnerColumn.name, .boolean).notNull().defaults(to: true)
        table.add(column: RuuviTagSQLite.owner.name, .text)
        table.add(column: RuuviTagSQLite.isCloudSensor.name, .boolean)
        table.add(column: RuuviTagSQLite.firmwareVersionColumn.name, .text)
        table.add(column: RuuviTagSQLite.canShareColumn.name, .boolean).defaults(to: false)
        table.add(column: RuuviTagSQLite.sharedToColumn.name, .text).defaults(to: "")
        table.add(column: RuuviTagSQLite.ownersPlan.name, .text)
        table.add(column: RuuviTagSQLite.maxHistoryDaysColumn.name, .integer)
        table.add(column: RuuviTagSQLite.serviceUUIDColumn.name, .text)
    }
}

private func addLegacyDataColumns(in db: Database) throws {
    try addDataColumnsThroughV5(in: db)
    try db.alter(table: RuuviTagDataSQLite.databaseTableName) { table in
        table.add(column: RuuviTagDataSQLite.versionColumn.name, .integer)
        table.add(column: RuuviTagDataSQLite.pm1Column.name, .double)
        table.add(column: RuuviTagDataSQLite.pm25Column.name, .double)
        table.add(column: RuuviTagDataSQLite.pm4Column.name, .double)
        table.add(column: RuuviTagDataSQLite.pm10Column.name, .double)
        table.add(column: RuuviTagDataSQLite.co2Column.name, .double)
        table.add(column: RuuviTagDataSQLite.vocColumn.name, .double)
        table.add(column: RuuviTagDataSQLite.noxColumn.name, .double)
        table.add(column: RuuviTagDataSQLite.luminanceColumn.name, .double)
        table.add(column: RuuviTagDataSQLite.dbaAvgColumn.name, .double)
        table.add(column: RuuviTagDataSQLite.dbaPeakColumn.name, .double)
        table.add(column: RuuviTagDataSQLite.dbaInstantColumn.name, .double)
    }
}

private func addDataColumnsThroughV5(in db: Database) throws {
    try db.alter(table: RuuviTagDataSQLite.databaseTableName) { table in
        table.add(column: RuuviTagDataSQLite.temperatureOffsetColumn.name, .double).notNull().defaults(to: 0.0)
        table.add(column: RuuviTagDataSQLite.humidityOffsetColumn.name, .double).notNull().defaults(to: 0.0)
        table.add(column: RuuviTagDataSQLite.pressureOffsetColumn.name, .double).notNull().defaults(to: 0.0)
        table.add(column: RuuviTagDataSQLite.sourceColumn.name, .text).notNull().defaults(to: "unknown")
        table.add(column: RuuviTagDataSQLite.luidColumn.name, .text)
    }
}

private func createMinimalTagTable(in db: Database) throws {
    try db.execute(
        sql: """
        CREATE TABLE \(RuuviTagSQLite.databaseTableName) (
            \(RuuviTagSQLite.idColumn.name) TEXT NOT NULL PRIMARY KEY,
            \(RuuviTagSQLite.macColumn.name) TEXT,
            \(RuuviTagSQLite.luidColumn.name) TEXT,
            \(RuuviTagSQLite.nameColumn.name) TEXT NOT NULL,
            \(RuuviTagSQLite.isConnectableColumn.name) BOOLEAN NOT NULL
        )
        """
    )
}

private func createMinimalDataTable(in db: Database) throws {
    try db.execute(
        sql: """
        CREATE TABLE \(RuuviTagDataSQLite.databaseTableName) (
            \(RuuviTagDataSQLite.idColumn.name) TEXT NOT NULL PRIMARY KEY,
            \(RuuviTagDataSQLite.ruuviTagIdColumn.name) TEXT NOT NULL,
            \(RuuviTagDataSQLite.dateColumn.name) DATETIME NOT NULL
        )
        """
    )
}

private func createMinimalLatestDataTable(in db: Database) throws {
    try db.execute(
        sql: """
        CREATE TABLE \(RuuviTagLatestDataSQLite.databaseTableName) (
            \(RuuviTagLatestDataSQLite.idColumn.name) TEXT NOT NULL PRIMARY KEY,
            \(RuuviTagLatestDataSQLite.ruuviTagIdColumn.name) TEXT NOT NULL,
            \(RuuviTagLatestDataSQLite.dateColumn.name) DATETIME NOT NULL,
            \(RuuviTagLatestDataSQLite.sourceColumn.name) TEXT NOT NULL
        )
        """
    )
}

private func createMinimalSensorSettingsTable(in db: Database) throws {
    try db.execute(
        sql: """
        CREATE TABLE \(SensorSettingsSQLite.databaseTableName) (
            \(SensorSettingsSQLite.idColumn.name) TEXT NOT NULL PRIMARY KEY,
            \(SensorSettingsSQLite.luidColumn.name) TEXT,
            \(SensorSettingsSQLite.macIdColumn.name) TEXT,
            \(SensorSettingsSQLite.temperatureOffsetColumn.name) DOUBLE,
            \(SensorSettingsSQLite.humidityOffsetColumn.name) DOUBLE,
            \(SensorSettingsSQLite.pressureOffsetColumn.name) DOUBLE
        )
        """
    )
}

private func temporaryDatabasePath() -> String {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    return directory.appendingPathComponent("ruuvi-context-\(UUID().uuidString).sqlite").path
}

private let contextMigrationNames = [
    "Create RuuviTagSQLite table",
    "Add isClaimedColumn column",
    "Create SensorSettingsSQLite table",
    "Create RuuviTagDataSQLite source column",
    "Create RuuviTagDataSQLite luid column",
    "Create RuuviTagSQLite isCloudSensor column",
    "Create RuuviTagSQLite firmwareVersion column",
    "Create RuuviTagLatestDataSQLite table",
    "Create RuuviCloudRequestQueueSQLite table",
    "Create RuuviTagSQLite canShare column",
    "Create RuuviTagSQLite sharedTo column",
    "Create RuuviTagSQLite ownersPlan column",
    "Create RuuviTagSQLite maxHistoryDays column",
    "Create RuuviCloudSensorSubscription table",
    "Create RuuviTagSQLite serviceUUID column",
    "Create RuuviTagDataSQLite version column",
    "Add new columns to RuuviTagDataSQLite and RuuviTagLatestDataSQLite",
    "Add new column to RuuviTagDataSQLite and RuuviTagLatestDataSQLite",
    "Add display order columns to SensorSettingsSQLite",
    "Add lastUpdated columns",
    "Add description columns to SensorSettingsSQLite",
]
