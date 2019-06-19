import RealmSwift

class MigrationManagerToVIPER: MigrationManager {
    func migrateIfNeeded() {
        let config = Realm.Configuration(
            schemaVersion: 2,
            migrationBlock: { migration, oldSchemaVersion in
                if (oldSchemaVersion < 2) {
                    
                }
        })
        
        // Tell Realm to use this new configuration object for the default Realm
        Realm.Configuration.defaultConfiguration = config
    }
}
