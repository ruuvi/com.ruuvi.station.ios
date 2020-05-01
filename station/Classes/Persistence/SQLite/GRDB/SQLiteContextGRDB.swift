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

}
