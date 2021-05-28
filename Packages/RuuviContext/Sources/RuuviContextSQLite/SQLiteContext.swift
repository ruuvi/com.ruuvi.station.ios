import Foundation

public protocol SQLiteContext {
    var database: GRDBDatabase { get }
}

public protocol SQLiteContextFactory {
    func create() -> SQLiteContext
}
