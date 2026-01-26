import Foundation
import GRDB

public protocol SQLiteContext: Sendable {
    var database: GRDBDatabase { get }
}

public protocol SQLiteContextFactory {
    func create() -> SQLiteContext
}

public protocol GRDBDatabase: Sendable {
    var dbPool: DatabasePool { get }
    var dbPath: String { get }

    func migrateIfNeeded()
}
