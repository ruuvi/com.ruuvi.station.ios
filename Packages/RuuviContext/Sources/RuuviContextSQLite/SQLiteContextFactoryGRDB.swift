#if SWIFT_PACKAGE
    import RuuviOntologySQLite
    import RuuviOntology
    import RuuviContext
#endif
import Foundation

public final class SQLiteContextFactoryGRDB: SQLiteContextFactory {
    public init() {}

    /// Opens and migrates an isolated database. Errors leave existing data intact.
    public func create(at url: URL) throws -> SQLiteContext {
        let database = try SQLiteGRDBDatabase(path: url.path)
        try database.migrateIfNeeded()
        return SQLiteContextGRDB(database: database)
    }

    public func create() -> SQLiteContext {
        SQLiteContextGRDB()
    }
}
