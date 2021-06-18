import Foundation
import RuuviContext

public final class SQLiteContextFactoryGRDB: SQLiteContextFactory {
    public init() {}

    public func create() -> SQLiteContext {
        return SQLiteContextGRDB()
    }
}
