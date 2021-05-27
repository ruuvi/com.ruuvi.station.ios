import Foundation

public protocol SQLiteContext {
    var database: GRDBDatabase { get }
}
