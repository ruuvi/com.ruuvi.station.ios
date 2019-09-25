import RealmSwift

class MigrationManagerToVIPER: MigrationManager {
    
    var backgroundPersistence: BackgroundPersistence!
    var settings: Settings!
    
    func migrateIfNeeded() {
        let config = Realm.Configuration(
            schemaVersion: 6,
            migrationBlock: { migration, oldSchemaVersion in
                if (oldSchemaVersion < 2) {
                    migration.enumerateObjects(ofType: "RuuviTag", { (oldObject, newObject) in
                        
                        if let uuid = oldObject?["uuid"] as? String,
                            let name = oldObject?["name"] as? String,
                            let version = oldObject?["dataFormat"] as? Int,
                            let mac = oldObject?["mac"] as? String {
                            
                            var realName: String
                            if name.isEmpty {
                                if mac.isEmpty {
                                    realName = uuid
                                } else {
                                    realName = mac
                                }
                            } else {
                                realName = name
                            }
                            
                            let ruuviTag = migration.create(RuuviTagRealm.className(), value: ["uuid": uuid, "name": realName, "version": version, "mac": mac])
                            
                            if let temperature = oldObject?["temperature"] as? Double,
                                let humidity = oldObject?["humidity"] as? Double,
                                let pressure = oldObject?["pressure"] as? Double,
                                let accelerationX = oldObject?["accelerationX"] as? Double,
                                let accelerationY = oldObject?["accelerationY"] as? Double,
                                let accelerationZ = oldObject?["accelerationZ"] as? Double,
                                let rssi = oldObject?["rssi"] as? Int,
                                let voltage = oldObject?["voltage"] as? Double,
                                let movementCounter = oldObject?["movementCounter"] as? Int,
                                let measurementSequenceNumber = oldObject?["measurementSequenceNumber"] as? Int,
                                let txPower = oldObject?["txPower"] as? Int,
                                let updatedAt = oldObject?["updatedAt"] as? NSDate {
                             migration.create(RuuviTagDataRealm.className(), value: ["ruuviTag": ruuviTag, "date": updatedAt, "rssi": rssi, "celsius": temperature, "humidity": humidity, "pressure": pressure, "accelerationX": accelerationX, "accelerationY": accelerationY, "accelerationZ": accelerationZ, "voltage": voltage, "movementCounter": movementCounter, "measurementSequenceNumber": measurementSequenceNumber, "txPower": txPower])
                            }
                        }
                        
                        if let uuid = oldObject?["uuid"] as? String, let id = oldObject?["defaultBackground"] as? Int {
                            self.backgroundPersistence.setBackground(id, for: uuid)
                        }
                        
                    })
                } else if oldSchemaVersion < 3 {
                    migration.enumerateObjects(ofType: RuuviTagDataRealm.className()) { oldObject, newObject in
                        if let value = oldObject?["celsius"] as? Double {
                            newObject?["celsius"] = value
                        }
                        if let value = oldObject?["humidity"] as? Double {
                            newObject?["humidity"] = value
                        }
                        if let value = oldObject?["pressure"] as? Double {
                            newObject?["pressure"] = value
                        }
                    }
                } else if oldSchemaVersion < 4 {
                    migration.enumerateObjects(ofType: WebTagRealm.className(), { (oldObject, newObject) in
                        if let location = oldObject?["location"] as? WebTagLocationRealm, let city = location.city {
                            newObject?["name"] = city
                        } else {
                            newObject?["name"] = ""
                        }
                    })
                } else if oldSchemaVersion < 5 {
                    // do nothing
                } else if oldSchemaVersion < 6 {
                    migration.deleteData(forType: RuuviTagDataRealm.className())
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
