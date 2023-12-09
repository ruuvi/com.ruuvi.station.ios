import Foundation

public final class SQLiteContextFactoryGRDB: SQLiteContextFactory {
    public init() {}

    public func create() -> SQLiteContext {
        SQLiteContextGRDB()
    }
}
