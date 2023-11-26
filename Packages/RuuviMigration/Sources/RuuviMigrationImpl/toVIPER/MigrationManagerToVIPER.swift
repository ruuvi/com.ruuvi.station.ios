import RealmSwift
import Foundation
import RuuviOntology
import RuuviLocal
import RuuviMigration
#if canImport(RuuviOntologyRealm)
import RuuviOntologyRealm
#endif

public final class MigrationManagerToVIPER: RuuviMigration {
    private let localImages: RuuviLocalImages
    private var settings: RuuviLocalSettings

    public init(
        localImages: RuuviLocalImages,
        settings: RuuviLocalSettings
    ) {
        self.localImages = localImages
        self.settings = settings
    }

    public func migrateIfNeeded() {
        let config = Realm.Configuration(
            schemaVersion: 11,
            migrationBlock: { [weak self] migration, oldSchemaVersion in
                if oldSchemaVersion < 2 {
                    self?.from1to2(migration)
                } else if oldSchemaVersion < 3 {
                    self?.from2to3(migration)
                } else if oldSchemaVersion < 4 {
                    self?.from3to4(migration)
                } else if oldSchemaVersion < 8 {
                    self?.deleteRuuviTagData(migration)
                }
        }, shouldCompactOnLaunch: { totalBytes, usedBytes in
            let fiveHundredMegabytes = 500 * 1024 * 1024
            return (totalBytes > fiveHundredMegabytes) && (Double(usedBytes) / Double(totalBytes)) < 0.5
        })

        // Tell Realm to use this new configuration object for the default Realm
        Realm.Configuration.defaultConfiguration = config

        do {
            _ = try Realm()
        } catch {
            if let url = Realm.Configuration.defaultConfiguration.fileURL {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    print(error.localizedDescription)
                }
            }
        }

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

    private func from1to2(_ migration: Migration) {
        migration.enumerateObjects(ofType: "RuuviTag", { (oldObject, _) in

            if let uuid = oldObject?["uuid"] as? String,
                let name = oldObject?["name"] as? String,
                let version = oldObject?["dataFormat"] as? Int,
                let mac = oldObject?["mac"] as? String {

                let realName = real(name, mac, uuid)
                let ruuviTag = migration.create(RuuviTagRealm.className(),
                                                value: ["uuid": uuid,
                                                        "name": realName,
                                                        "version": version,
                                                        "mac": mac])

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
                    migration.create(RuuviTagDataRealm.className(),
                                     value: ["ruuviTag": ruuviTag,
                                             "date": updatedAt,
                                             "rssi": rssi,
                                             "celsius": temperature,
                                             "humidity": humidity,
                                             "pressure": pressure,
                                             "accelerationX": accelerationX,
                                             "accelerationY": accelerationY,
                                             "accelerationZ": accelerationZ,
                                             "voltage": voltage,
                                             "movementCounter": movementCounter,
                                             "measurementSequenceNumber": measurementSequenceNumber,
                                             "txPower": txPower])
                }
            }

            if let uuid = oldObject?["uuid"] as? String, let id = oldObject?["defaultBackground"] as? Int {
                localImages.setBackground(id, for: uuid.luid)
            }
        })
    }

    private func from2to3(_ migration: Migration) {
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
    }

    private func from3to4(_ migration: Migration) {
        deleteRuuviTagData(migration)
    }

    private func deleteRuuviTagData(_ migration: Migration) {
        migration.deleteData(forType: RuuviTagDataRealm.className())
    }

    private func real(_ name: String, _ mac: String, _ uuid: String) -> String {
        let realName: String
        if name.isEmpty {
            if mac.isEmpty {
                realName = uuid
            } else {
                realName = mac
            }
        } else {
            realName = name
        }
        return realName
    }

}
