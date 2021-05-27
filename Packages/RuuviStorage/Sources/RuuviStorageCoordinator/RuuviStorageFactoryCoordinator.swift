import Foundation

public final class RuuviStorageFactoryCoordinator: RuuviStorageFactory {
    public func create() -> RuuviStorage {
        let realmContext = RealmContextImpl()
        let realm = RuuviStoragePersistenceRealm(context: realmContext)
        let sqliteContext = SQLiteContextGRDB()
        let sqlite = RuuviStoragePersistenceSQLite(context: sqliteContext)
        return RuuviStorageCoordinator(sqlite: sqlite, realm: realm)
    }
}
