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
}

class SQLiteGRDBDatabase: GRDBDatabase {

    static let shared: SQLiteGRDBDatabase = {
        let instance = try! SQLiteGRDBDatabase()
        return instance
    }()

    private static var databasePath: String {
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
    public static func tryMigrate() {
        let database = SQLiteGRDBDatabase.shared

        do {
            try database.migrate(dbPool: database.dbPool)
        } catch {
            database.recreate()
            try! database.migrate(dbPool: database.dbPool)
        }
    }

    private func migrate(dbPool: DatabasePool) throws {
        var migrator = GRDB.DatabaseMigrator()

        // v1
        migrator.registerMigration("Create RuuviTagSQLite table") { db in
            try RuuviTagSQLite.createTable(in: db)
        }

        try migrator.migrate(dbPool)
    }
}
