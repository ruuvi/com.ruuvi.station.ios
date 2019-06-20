import RealmSwift

class MigrationManagerToVIPER: MigrationManager {
    
    var backgroundPersistence: BackgroundPersistence!
    var settings: Settings!
    
    func migrateIfNeeded() {
        let config = Realm.Configuration(
            schemaVersion: 2,
            migrationBlock: { migration, oldSchemaVersion in
                if (oldSchemaVersion < 2) {
                    migration.enumerateObjects(ofType: "RuuviTag", { (oldObject, newObject) in
                        
                        if let uuid = oldObject?["uuid"] as? String,
                            let name = oldObject?["name"] as? String,
                            let version = oldObject?["dataFormat"] as? Int,
                            let mac = oldObject?["mac"] as? String {
                            migration.create(RuuviTagRealm.className(), value: ["uuid": uuid, "name": name, "version": version, "mac": mac])
                        }
                        
                        if let uuid = oldObject?["uuid"] as? String, let id = oldObject?["defaultBackground"] as? Int {
                            self.backgroundPersistence.setBackground(id, for: uuid)
                        }
                        
                    })
                }
        })
        
        // Tell Realm to use this new configuration object for the default Realm
        Realm.Configuration.defaultConfiguration = config
        
        if !UserDefaults.standard.bool(forKey: "MigrationManagerToVIPER.useFahrenheit.checked") {
            UserDefaults.standard.set(true, forKey: "MigrationManagerToVIPER.useFahrenheit.checked")
            let useFahrenheit = UserDefaults.standard.bool(forKey: "useFahrenheit")
            settings.temperatureUnit = useFahrenheit ? .fahrenheit : .celsius
        }
        
        if !UserDefaults.standard.bool(forKey: "MigrationManagerToVIPER.hasShownWelcome.checked") {
            UserDefaults.standard.set(true, forKey: "MigrationManagerToVIPER.hasShownWelcome.checked")
            settings.welcomeShown = UserDefaults.standard.bool(forKey: "hasShownWelcome")
        }
        
        if !UserDefaults.standard.bool(forKey: "MigrationManagerToVIPER.hasShownSwipe.checked") {
            UserDefaults.standard.set(true, forKey: "MigrationManagerToVIPER.hasShownSwipe.checked")
            let hasShownSwipe = UserDefaults.standard.bool(forKey: "hasShownSwipe")
            UserDefaults.standard.set(hasShownSwipe, forKey: "DashboardScrollViewController.hasShownSwipeAlert")
        }
    }
}
