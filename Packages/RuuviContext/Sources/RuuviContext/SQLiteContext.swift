import Foundation
import GRDB

public protocol SQLiteContext {
    var database: GRDBDatabase { get }
}

public protocol SQLiteContextFactory {
    func create() -> SQLiteContext
}

public protocol GRDBDatabase {
    var dbPool: DatabasePool { get }
    var dbPath: String { get }

    func migrateIfNeeded()
}
