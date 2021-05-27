import Foundation

public final class RuuviStorageFactoryCoordinator: RuuviStorageFactory {
    public func create() -> RuuviStorage {
        let realm = RuuviStoragePersistenceRealm()
        let sqliteContext = SQLiteContextGRDB()
        let sqlite = RuuviStoragePersistenceSQLite(database: sqliteContext.database)
        return RuuviStorageCoordinator(sqlite: sqlite, realm: realm)
    }
}
