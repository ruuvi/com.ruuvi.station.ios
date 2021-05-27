import Foundation
import RuuviContext

public final class RuuviStorageFactoryCoordinator: RuuviStorageFactory {
    public func create(realm: RealmContext, sqlite: SQLiteContext) -> RuuviStorage {
        let realmStorage = RuuviStoragePersistenceRealm(context: realm)
        let sqliteStorage = RuuviStoragePersistenceSQLite(context: sqlite)
        return RuuviStorageCoordinator(sqlite: sqliteStorage, realm: realmStorage)
    }
}
