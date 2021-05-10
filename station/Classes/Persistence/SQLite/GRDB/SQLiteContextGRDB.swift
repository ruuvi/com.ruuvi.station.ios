import Foundation
import GRDB

class SQLiteContextGRDB: SQLiteContext {
    let database: GRDBDatabase = SQLiteGRDBDatabase.shared
}

protocol DatabaseService {
    associatedtype Entity: PersistableRecord

    var database: GRDBDatabase { get }
}

protocol GRDBDatabase {
    var dbPool: DatabasePool { get }

    func migrateIfNeeded()
}

class SQLiteGRDBDatabase: GRDBDatabase {

    static let shared: SQLiteGRDBDatabase = {
        let instance = try! SQLiteGRDBDatabase()
        return instance
    }()

    static var databasePath: String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                                .userDomainMask, true).first! as NSString
        let databasePath = documentsPath.appendingPathComponent("grdb.sqlite")
        return databasePath
    }

    private(set) var dbPool: DatabasePool

    private init() throws {
        dbPool = try DatabasePool(path: SQLiteGRDBDatabase.databasePath)
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

    private func migrate(dbPool: DatabasePool) throws {
        var migrator = GRDB.DatabaseMigrator()

        // v1
        migrator.registerMigration("Create RuuviTagSQLite table") { db in
            try RuuviTagSQLite.createTable(in: db)
            try RuuviTagDataSQLite.createTable(in: db)
        }

        // v2
        migrator.registerMigration("Add networkProvider column") { (db) in
            guard try db.columns(in: RuuviTagSQLite.databaseTableName)
                    .contains(where: {$0.name == RuuviTagSQLite.networkProviderColumn.name}) == false else {
                return
            }
            try db.alter(table: RuuviTagSQLite.databaseTableName) { (t) in
                t.add(column: RuuviTagSQLite.networkProviderColumn.name, .integer)
                t.add(column: RuuviTagSQLite.isClaimedColumn.name, .boolean)
                    .notNull()
                    .defaults(to: false)
                t.add(column: RuuviTagSQLite.isOwnerColumn.name, .boolean)
                    .notNull()
                    .defaults(to: false)
                t.add(column: RuuviTagSQLite.owner.name, .text)
            }
        }

        try migrator.migrate(dbPool)
    }
}
